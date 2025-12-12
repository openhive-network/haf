#!/usr/bin/env python
"""
Tests for SQL code generation from OpenAPI schemas.

Tests:
- Enum type generation
- Object type generation  
- Function signature generation
- SQL keywords detection
"""

import sys
from io import StringIO
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(SCRIPTS_DIR))

import process_openapi


class TestEnumCodeGeneration:
    """Test SQL enum type generation from OpenAPI enum schema."""

    def test_enum_type_generation(self, reset_global_state):
        """Test SQL enum type generation from OpenAPI enum schema."""
        output = StringIO()
        enum_values = ['all', 'token', 'nft']
        process_openapi.generate_code_for_enum_openapi_fragment('test_app.asset_type', enum_values, output)
        result = output.getvalue()
        
        assert 'DROP TYPE IF EXISTS test_app.asset_type CASCADE;' in result
        assert 'CREATE TYPE test_app.asset_type AS ENUM (' in result
        assert "'all'" in result
        assert "'token'" in result
        assert "'nft'" in result

    def test_enum_with_special_characters(self, reset_global_state):
        """Test enum generation with special characters in values."""
        output = StringIO()
        enum_values = ['value-with-dash', 'value_with_underscore', 'CamelCase']
        process_openapi.generate_code_for_enum_openapi_fragment('test_app.special_enum', enum_values, output)
        result = output.getvalue()
        
        assert "'value-with-dash'" in result
        assert "'value_with_underscore'" in result
        assert "'CamelCase'" in result

    def test_enum_single_value(self, reset_global_state):
        """Test enum generation with single value."""
        output = StringIO()
        enum_values = ['only_value']
        process_openapi.generate_code_for_enum_openapi_fragment('test_app.single_enum', enum_values, output)
        result = output.getvalue()
        
        assert "'only_value'" in result
        # Should not have trailing comma
        assert ",\n)" not in result


class TestObjectCodeGeneration:
    """Test SQL object type generation from OpenAPI object schema."""

    def test_object_type_generation(self, reset_global_state):
        """Test SQL object type generation from OpenAPI object schema."""
        output = StringIO()
        object_properties = {
            'account_name': {'type': 'string'},
            'balance': {'type': 'integer'},
            'is_active': {'type': 'boolean'}
        }
        process_openapi.generate_code_for_object_openapi_fragment('test_app.account_info', object_properties, output)
        result = output.getvalue()
        
        assert 'DROP TYPE IF EXISTS test_app.account_info CASCADE;' in result
        assert 'CREATE TYPE test_app.account_info AS (' in result
        assert '"account_name" TEXT' in result
        assert '"balance" INT' in result
        assert '"is_active" BOOLEAN' in result

    def test_object_with_custom_datatypes(self, reset_global_state):
        """Test object generation with custom SQL datatypes."""
        output = StringIO()
        object_properties = {
            'id': {'type': 'integer', 'x-sql-datatype': 'BIGINT'},
            'amount': {'type': 'number', 'x-sql-datatype': 'NUMERIC(18,6)'}
        }
        process_openapi.generate_code_for_object_openapi_fragment('test_app.custom_types', object_properties, output)
        result = output.getvalue()
        
        assert '"id" BIGINT' in result
        assert '"amount" NUMERIC(18,6)' in result

    def test_object_with_datetime(self, reset_global_state):
        """Test object generation with datetime field."""
        output = StringIO()
        object_properties = {
            'created_at': {'type': 'string', 'format': 'date-time'},
            'name': {'type': 'string'}
        }
        process_openapi.generate_code_for_object_openapi_fragment('test_app.timestamped', object_properties, output)
        result = output.getvalue()
        
        assert '"created_at" TIMESTAMP' in result
        assert '"name" TEXT' in result


class TestFunctionSignatureGeneration:
    """Test SQL function signature generation from OpenAPI paths."""

    def test_function_signature_with_parameters(self, reset_global_state):
        """Test SQL function signature generation with parameters."""
        output = StringIO()
        method_fragment = {
            'operationId': 'test_endpoints.get_account',
            'parameters': [
                {'name': 'account_name', 'schema': {'type': 'string'}},
                {'name': 'page', 'schema': {'type': 'integer', 'default': 1}}
            ],
            'responses': {
                '200': {
                    'content': {
                        'application/json': {
                            'schema': {'type': 'object'}
                        }
                    }
                }
            }
        }
        process_openapi.generate_function_signature('get', method_fragment, output)
        result = output.getvalue()
        
        assert 'DROP FUNCTION IF EXISTS test_endpoints.get_account;' in result
        assert 'CREATE OR REPLACE FUNCTION test_endpoints.get_account(' in result
        assert '"account_name" TEXT' in result
        assert '"page" INT = 1' in result
        assert 'RETURNS object' in result

    def test_function_signature_without_parameters(self, reset_global_state):
        """Test SQL function signature generation without parameters."""
        output = StringIO()
        method_fragment = {
            'operationId': 'test_endpoints.get_all',
            'responses': {
                '200': {
                    'content': {
                        'application/json': {
                            'schema': {'type': 'object'}
                        }
                    }
                }
            }
        }
        process_openapi.generate_function_signature('get', method_fragment, output)
        result = output.getvalue()
        
        assert 'DROP FUNCTION IF EXISTS test_endpoints.get_all;' in result
        assert 'CREATE OR REPLACE FUNCTION test_endpoints.get_all()' in result
        assert 'RETURNS object' in result

    def test_function_with_null_parameters(self, reset_global_state):
        """Test SQL function signature generation with null parameters."""
        output = StringIO()
        method_fragment = {
            'operationId': 'test_endpoints.get_data',
            'parameters': None,
            'responses': {
                '200': {
                    'content': {
                        'application/json': {
                            'schema': {'type': 'object'}
                        }
                    }
                }
            }
        }
        process_openapi.generate_function_signature('get', method_fragment, output)
        result = output.getvalue()
        
        assert 'CREATE OR REPLACE FUNCTION test_endpoints.get_data()' in result


class TestSQLKeywords:
    """Test SQL keyword detection."""

    def test_known_keywords(self):
        """Test that known SQL keywords are detected."""
        keywords = ['SELECT', 'FROM', 'WHERE', 'INT', 'BOOLEAN', 'TIMESTAMP', 'VARCHAR', 'BIGINT']
        for keyword in keywords:
            assert process_openapi.is_sql_keyword(keyword), f"{keyword} should be recognized as SQL keyword"

    def test_non_keywords(self):
        """Test that non-keywords are not detected as keywords."""
        non_keywords = ['account_name', 'my_table', 'get_data', 'foo', 'bar']
        for word in non_keywords:
            assert not process_openapi.is_sql_keyword(word), f"{word} should NOT be recognized as SQL keyword"

    def test_case_insensitive(self):
        """Test that keyword detection is case-insensitive."""
        assert process_openapi.is_sql_keyword('select')
        assert process_openapi.is_sql_keyword('SELECT')
        assert process_openapi.is_sql_keyword('Select')


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
