#! /usr/bin/env python
import yaml
import json
import re
import sys

from pathlib import Path

from deepmerge import always_merger
from jsonpointer import resolve_pointer

collected_openapi_fragments = {}

def merge_openapi_fragment(new_fragment):
    global collected_openapi_fragments
    # sys.stdout.write('Before:')
    # sys.stdout.write(yaml.dump(collected_openapi_fragments, Dumper=yaml.Dumper))
    collected_openapi_fragments = always_merger.merge(collected_openapi_fragments, new_fragment)
    # sys.stdout.write('After:')
    # sys.stdout.write(yaml.dump(collected_openapi_fragments, Dumper=yaml.Dumper))

def generate_code_for_enum_openapi_fragment(enum_name, enum_values_openapi_fragment, sql_output):
    sql_output.write('-- openapi-generated-code-begin\n')
    sql_output.write(f'DROP TYPE IF EXISTS {enum_name} CASCADE;\n')
    sql_output.write(f'CREATE TYPE {enum_name} AS ENUM (\n')
    sql_output.write(',\n'.join([f'    \'{enum_value}\'' for enum_value in enum_values_openapi_fragment]))
    sql_output.write('\n);\n')
    sql_output.write('-- openapi-generated-code-end\n')

def generate_type_string_from_schema(schema):
    if 'x-sql-datatype' in schema:
        return schema['x-sql-datatype']
    elif '$ref' in schema:
        reference = schema['$ref']
        # openapi references typically start with #, but that's not a valid json pointer
        if len(reference) > 0 and reference[0] == '#':
            reference = reference[1:]
        referent = resolve_pointer(collected_openapi_fragments, reference)
        if 'type' in referent and referent['type'] == 'array':
            # special case, if it's an array, we don't use the name of the type, we say SETOF the contained type
            if 'items' in referent:
                return 'SETOF ' + generate_type_string_from_schema(referent['items'])
        else:
            return reference.split('/')[-1]
    elif 'type' in schema:
        schema_type = schema['type']
        if schema_type == 'integer':
            return 'INT'
        elif schema_type == 'string':
            if 'format' in schema:
                if schema['format'] == 'date-time':
                    return 'TIMESTAMP'
            return 'TEXT'
        elif schema_type == 'boolean':
            return 'BOOLEAN'
        elif schema_type == 'number':
            return 'FLOAT'
        else:
            assert(False)

def generate_default_value_string_from_schema(schema):
    if 'default' in schema:
        default_value = str(schema['default'])

        requires_quoting = True
        if default_value  == str(None):
            default_value = 'NULL'
            requires_quoting = False
        elif 'type' in schema:
            schema_type = schema['type']
            if schema_type == 'integer' or schema_type == 'number' or  schema_type == 'boolean':
                requires_quoting = False
        elif 'x-sql-datatype' in schema:
            sql_datatype = schema['x-sql-datatype']
            if sql_datatype.upper() == 'INT' or sql_datatype.upper() == 'FLOAT':
                requires_quoting = False
        elif '$ref' in schema:
            reference = schema['$ref']
            if len(reference) > 0 and reference[0] == '#':
                reference = reference[1:]
            referent = resolve_pointer(collected_openapi_fragments, reference)
        if requires_quoting:
            default_value = f'\'{default_value}\''
    elif 'x-sql-default-value' in schema:
        # it's assumed that x-sql-default-value is already properly quoted
        # that enables you to use either a string like '2000-01-01' or an expression like NOW()
        default_value = str(schema['x-sql-default-value'])
    else:
        return ''

    return ' = ' + default_value


def generate_type_field_or_parameter_string_from_openapi_fragment(property_name, property_properties, include_default_values = False):
    type_string = generate_type_string_from_schema(property_properties)
    type_field_string = f'    "{property_name}" {type_string}'
    if include_default_values:
        type_field_string += generate_default_value_string_from_schema(property_properties)
    return type_field_string

def generate_code_for_object_openapi_fragment(object_name, object_openapi_fragment, sql_output):
    sql_output.write('-- openapi-generated-code-begin\n')
    sql_output.write(f'DROP TYPE IF EXISTS {object_name} CASCADE;\n')
    sql_output.write(f'CREATE TYPE {object_name} AS (\n')
    sql_output.write(',\n'.join([generate_type_field_or_parameter_string_from_openapi_fragment(property_name, property_properties) for property_name, property_properties in object_openapi_fragment.items()]))
    sql_output.write('\n);\n')
    sql_output.write('-- openapi-generated-code-end\n')

def generate_function_signature(method, method_fragment, sql_output):
    def generate_parameter_string(parameter_openapi_fragment, include_default_values):
        name = parameter_openapi_fragment['name']
        schema = parameter_openapi_fragment['schema']
        return generate_type_field_or_parameter_string_from_openapi_fragment(name, schema, include_default_values = include_default_values)

    def generate_parameter_list(parameters_openapi_fragment, include_default_values):
        return ',\n'.join([generate_parameter_string(param, include_default_values) for param in parameters_openapi_fragment])

    assert('operationId' in method_fragment)
    operationId = method_fragment['operationId']


    assert('responses' in method_fragment)
    responses = method_fragment['responses']
    assert('200' in responses)
    ok_response = responses['200']
    assert('content' in ok_response)
    content = ok_response['content']
    assert('application/json' in content)
    json_response = content['application/json']
    assert('schema' in json_response)
    response_schema = json_response['schema']
    response_type_string = generate_type_string_from_schema(response_schema)


    sql_output.write('-- openapi-generated-code-begin\n')
    if 'parameters' not in method_fragment or method_fragment['parameters'] == None:
        sql_output.write(f'DROP FUNCTION IF EXISTS {operationId};\n')
        sql_output.write(f'CREATE OR REPLACE FUNCTION {operationId}()\n')
        sql_output.write(f'RETURNS {response_type_string} \n')
        sql_output.write('-- openapi-generated-code-end\n')
    else:
        parameters_openapi_fragment = method_fragment['parameters']
        #parameters = generate_parameter_list(parameters_openapi_fragment)
        #(\n{generate_parameter_list(parameters_openapi_fragment, False)}\n) 
        #- removed because on runtime code upgrade the functions that might have parameter changes won't be dropped due to parameters not matching
        sql_output.write(f'DROP FUNCTION IF EXISTS {operationId};\n')
        sql_output.write(f'CREATE OR REPLACE FUNCTION {operationId}(\n{generate_parameter_list(parameters_openapi_fragment, True)}\n)\n')
        sql_output.write(f'RETURNS {response_type_string} \n')
        sql_output.write('-- openapi-generated-code-end\n')

def generate_code_from_openapi_fragment(openapi_fragment, sql_output):
    # figure out what type of fragment this is so we know what to generate
    if len(openapi_fragment) == 1:
        key = next(iter(openapi_fragment))
        if key == 'components':
            components = openapi_fragment[key]
            assert(len(components) == 1)
            assert('schemas' in components)
            schemas = components['schemas']
            assert(len(schemas) == 1)
            schema_name = next(iter(schemas))
            schema = schemas[schema_name]
            assert('type' in schema)
            if schema['type'] == 'string' and 'enum' in schema:
                generate_code_for_enum_openapi_fragment(schema_name, schema['enum'], sql_output)
            elif schema['type'] == 'object' and 'properties' in schema:
                generate_code_for_object_openapi_fragment(schema_name, schema['properties'], sql_output)
            elif schema['type'] == 'array':
                # don't generate code for arrays.  when these are returned, the generated SQL
                # uses SETOF underlying_data_type
                pass
            else:
                assert(False)
        elif key == 'paths':
            paths = openapi_fragment[key]
            assert(len(paths) == 1)
            path = next(iter(paths))
            methods = paths[path]
            assert(len(methods) == 1)
            method = next(iter(methods))
            method_fragment = methods[method]
            generate_function_signature(method, method_fragment, sql_output)
        else:
            # we don't know how to generate code for this fragment, assume it's just a fragment we pass through
            pass
    else:
        # we don't know how to generate code for this fragment, assume it's just a fragment
        pass

# return true if this is a PostgreSQL keyword.  List taken from https://www.postgresql.org/docs/current/sql-keywords-appendix.html
# excluding all keywords which are marked 'reserved', or 'non-reserved' but with qualifications
def is_sql_keyword(word):
    keywords = {'BETWEEN',
                'BIGINT',
                'BIT',
                'BOOLEAN',
                'COALESCE',
                'DEC',
                'DECIMAL',
                'EXISTS',
                'EXTRACT',
                'FLOAT',
                'GREATEST',
                'GROUPING',
                'INOUT',
                'INT',
                'INTEGER',
                'INTERVAL',
                'JSON_ARRAY',
                'JSON_ARRAYAGG',
                'JSON_OBJECT',
                'JSON_OBJECTAGG',
                'LEAST',
                'NATIONAL',
                'NCHAR',
                'NONE',
                'NORMALIZE',
                'NULLIF',
                'NUMERIC',
                'OUT',
                'OVERLAY',
                'POSITION',
                'REAL',
                'ROW',
                'SETOF',
                'SMALLINT',
                'SUBSTRING',
                'TIME',
                'TIMESTAMP',
                'TREAT',
                'TRIM',
                'VALUES',
                'VARCHAR',
                'XMLATTRIBUTES',
                'XMLCONCAT',
                'XMLELEMENT',
                'XMLEXISTS',
                'XMLFOREST',
                'XMLNAMESPACES',
                'XMLPARSE',
                'XMLPI',
                'XMLROOT',
                'XMLSERIALIZE',
                'XMLTABLE',
                'CHAR',
                'CHARACTER',
                'PRECISION',
                'DAY',
                'FILTER',
                'HOUR',
                'MINUTE',
                'MONTH',
                'OVER',
                'SECOND',
                'VARYING',
                'WITHIN',
                'WITHOUT',
                'YEAR',
                'ALL',
                'ANALYSE',
                'ANALYZE',
                'AND',
                'ANY',
                'ASC',
                'ASYMMETRIC',
                'BOTH',
                'CASE',
                'CAST',
                'CHECK',
                'COLLATE',
                'COLUMN',
                'CONSTRAINT',
                'CURRENT_CATALOG',
                'CURRENT_DATE',
                'CURRENT_ROLE',
                'CURRENT_TIME',
                'CURRENT_TIMESTAMP',
                'CURRENT_USER',
                'DEFAULT',
                'DEFERRABLE',
                'DESC',
                'DISTINCT',
                'DO',
                'ELSE',
                'END',
                'FALSE',
                'FOREIGN',
                'IN',
                'INITIALLY',
                'LATERAL',
                'LEADING',
                'LOCALTIME',
                'LOCALTIMESTAMP',
                'NOT',
                'NULL',
                'ONLY',
                'OR',
                'PLACING',
                'PRIMARY',
                'REFERENCES',
                'SELECT',
                'SESSION_USER',
                'SOME',
                'SYMMETRIC',
                'SYSTEM_USER',
                'TABLE',
                'THEN',
                'TRAILING',
                'TRUE',
                'UNIQUE',
                'USER',
                'USING',
                'VARIADIC',
                'WHEN',
                'AUTHORIZATION',
                'BINARY',
                'COLLATION',
                'CONCURRENTLY',
                'CROSS',
                'CURRENT_SCHEMA',
                'FREEZE',
                'FULL',
                'ILIKE',
                'INNER',
                'IS',
                'JOIN',
                'LEFT',
                'LIKE',
                'NATURAL',
                'OUTER',
                'RIGHT',
                'SIMILAR',
                'TABLESAMPLE',
                'VERBOSE',
                'ISNULL',
                'NOTNULL',
                'OVERLAPS',
                'ARRAY',
                'AS',
                'CREATE',
                'EXCEPT',
                'FETCH',
                'FOR',
                'FROM',
                'GRANT',
                'GROUP',
                'HAVING',
                'INTERSECT',
                'INTO',
                'LIMIT',
                'OFFSET',
                'ON',
                'ORDER',
                'RETURNING',
                'TO',
                'UNION',
                'WHERE',
                'WINDOW',
                'WITH'}
    return word.upper() in keywords


def dump_openapi_spec(sql_output):
    sql_output.write('-- openapi-generated-code-begin\n')
    sql_output.write('  openapi json = $$\n')
    sql_output.write(json.dumps(collected_openapi_fragments, indent = 2))
    sql_output.write('\n$$;\n')
    sql_output.write('-- openapi-generated-code-end\n')

def generate_rewrite_rules(rewrite_rules_file):
    if 'paths' in collected_openapi_fragments:
        with open(rewrite_rules_file, 'w') as rewrite_rules_file:
            # generate default rules that are always the same
            rewrite_rules_file.write(f'# default endpoint for everything else\n')
            rewrite_rules_file.write(f'rewrite ^/(.*)$ /rpc/$1 break;\n\n')
            rewrite_rules_file.write(f'# endpoint for openapi spec itself\n')
            rewrite_rules_file.write(f'rewrite ^/$ / break;\n\n')
            for path, methods_for_path in collected_openapi_fragments['paths'].items():
                for method, method_data in methods_for_path.items():
                    path_parts = path.split('/')
                    # paths in openapi spec will start with / and then the name of the API, like: GET /hafbe/witnesses
                    # an upstream server will remove the name of the API, so we get rid of it here:
                    if len(path_parts) > 1:
                        path_parts = path_parts[1:]
                    rewrite_parts = ['^']
                    query_parts = []
                    next_placeholder = 1
                    rpc_method_name = method_data['operationId'].split('.')[-1]
                    for path_part in path_parts:
                        assert(len(path_part) > 0)
                        if path_part[0] == '{' and path_part[-1] == '}':
                            rewrite_parts.append('([^/]+)')
                            param_name = path_part[1:-1]
                            query_parts.append(f'{param_name}=${next_placeholder}')
                            next_placeholder += 1
                            rewrite_required = True
                        else:
                            rewrite_parts.append(path_part)

                    rewrite_from = '/'.join(rewrite_parts)
                    if len(query_parts) > 0:
                        query_string = '?' + '&'.join(query_parts)
                    else:
                        query_string = ''
                    rewrite_to = f'/rpc/{rpc_method_name}{query_string}'
                    rewrite_rules_file.write(f'# endpoint for {method} {path}\n')
                    rewrite_rules_file.write(f'rewrite {rewrite_from} {rewrite_to} break;\n\n')

def process_sql_file(sql_input, sql_output):
    yaml_comment_path = []
    yaml_comment_lines = []
    in_yaml_comment = False
    in_generated_code = False

    def finish_comment():
        nonlocal yaml_comment_lines
        nonlocal yaml_comment_path
        comment_yaml = yaml.load(''.join(yaml_comment_lines), Loader=yaml.FullLoader)
        for path_element in reversed(yaml_comment_path):
            comment_yaml = {path_element: comment_yaml}
        if sql_output != None:
            generate_code_from_openapi_fragment(comment_yaml, sql_output)
        else:
            merge_openapi_fragment(comment_yaml)
        #print(comment_yaml)
        #sys.stdout.write(yaml.dump(comment_yaml, Dumper=yaml.Dumper))
        yaml_comment_lines = []
        yaml_comment_path = []

    for line in sql_input:
        if in_yaml_comment:
            if sql_output != None:
                sql_output.write(line)
            if re.match(r'^\s*\*\/\s*$', line):
                in_yaml_comment = False
                finish_comment()
                continue
            else:
                yaml_comment_lines.append(line)
        elif in_generated_code:
            if line == '-- openapi-generated-code-end\n':
                in_generated_code = False
                continue
        else:
            if line == '-- openapi-generated-code-begin\n':
                in_generated_code = True
                continue
            if sql_output != None:
                sql_output.write(line)

                matches_openapi_spec_comment = re.match(r'^\s*-- openapi-spec\s*$', line)
                if matches_openapi_spec_comment:
                    dump_openapi_spec(sql_output)

            matches_openapi_fragment = re.match(r'^\s*\/\*\*\s*openapi(?::((?:\w+)(?::\w+)*))?\s*$', line)
            if matches_openapi_fragment:
                if matches_openapi_fragment.group(1):
                    yaml_comment_path = matches_openapi_fragment.group(1).split(':')
                else:
                    yaml_comment_path = []
                in_yaml_comment = True

def process_sql_files(input_sql_filenames, output_dir = None):
    for input_sql_filename in input_sql_filenames:
        with open(input_sql_filename) as sql_input:
            if output_dir == None:
                process_sql_file(sql_input, None)
            else:
                output_sql_filename = output_dir / Path(input_sql_filename)
                output_sql_filename.parent.mkdir(parents = True, exist_ok = True)
                with output_sql_filename.open(mode = 'w') as sql_output:
                    process_sql_file(sql_input, sql_output)

# needs proper command-line parsing
output_dir = Path(sys.argv[1])
input_files = sys.argv[2:]
rewrite_rules_file = 'rewrite_rules.conf'

# Do a first pass that just collects all the openapi fragments
process_sql_files(input_files)
# Then a second pass that does the substitutions, writing output files to `output_dir`
process_sql_files(input_files, output_dir)
# and dump the nginx rewrite rules
generate_rewrite_rules(rewrite_rules_file)
