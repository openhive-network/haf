#!/usr/bin/env python
"""
Tests for SQL type generation from OpenAPI schemas.

Tests:
- Type string generation (integer, string, datetime, boolean, etc.)
- Default value generation
- Custom x-sql-datatype handling
- Array type handling
"""

import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(SCRIPTS_DIR))

import process_openapi


class TestTypeStringGeneration:
    """Test SQL type string generation from OpenAPI schema."""

    def test_integer_type(self, reset_global_state):
        """Test integer type conversion."""
        schema = {'type': 'integer'}
        result = process_openapi.generate_type_string_from_schema(schema)
        assert result == 'INT'

    def test_string_type(self, reset_global_state):
        """Test string type conversion."""
        schema = {'type': 'string'}
        result = process_openapi.generate_type_string_from_schema(schema)
        assert result == 'TEXT'

    def test_datetime_type(self, reset_global_state):
        """Test datetime type conversion."""
        schema = {'type': 'string', 'format': 'date-time'}
        result = process_openapi.generate_type_string_from_schema(schema)
        assert result == 'TIMESTAMP'

    def test_boolean_type(self, reset_global_state):
        """Test boolean type conversion."""
        schema = {'type': 'boolean'}
        result = process_openapi.generate_type_string_from_schema(schema)
        assert result == 'BOOLEAN'

    def test_number_type(self, reset_global_state):
        """Test number type conversion."""
        schema = {'type': 'number'}
        result = process_openapi.generate_type_string_from_schema(schema)
        assert result == 'FLOAT'

    def test_custom_sql_datatype(self, reset_global_state):
        """Test custom x-sql-datatype."""
        schema = {'type': 'integer', 'x-sql-datatype': 'BIGINT'}
        result = process_openapi.generate_type_string_from_schema(schema)
        assert result == 'BIGINT'

    def test_array_of_integers(self, reset_global_state):
        """Test array of integers type conversion."""
        schema = {'type': 'array', 'items': {'type': 'integer'}}
        result = process_openapi.generate_type_string_from_schema(schema)
        assert result == 'INT[]'

    def test_array_of_strings(self, reset_global_state):
        """Test array of strings type conversion."""
        schema = {'type': 'array', 'items': {'type': 'string'}}
        result = process_openapi.generate_type_string_from_schema(schema)
        assert result == 'TEXT[]'

    def test_object_type(self, reset_global_state):
        """Test object type conversion."""
        schema = {'type': 'object'}
        result = process_openapi.generate_type_string_from_schema(schema)
        assert result == 'object'


class TestDefaultValueGeneration:
    """Test default value string generation from OpenAPI schema."""

    def test_null_default(self, reset_global_state):
        """Test NULL default value."""
        schema = {'type': 'integer', 'default': None}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == ' = NULL'

    def test_integer_default(self, reset_global_state):
        """Test integer default value (no quoting)."""
        schema = {'type': 'integer', 'default': 100}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == ' = 100'

    def test_string_default(self, reset_global_state):
        """Test string default value (with quoting)."""
        schema = {'type': 'string', 'default': 'all'}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == " = 'all'"

    def test_boolean_default_true(self, reset_global_state):
        """Test boolean default value True (no quoting)."""
        schema = {'type': 'boolean', 'default': True}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == ' = True'

    def test_boolean_default_false(self, reset_global_state):
        """Test boolean default value False (no quoting)."""
        schema = {'type': 'boolean', 'default': False}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == ' = False'

    def test_number_default(self, reset_global_state):
        """Test number/float default value (no quoting)."""
        schema = {'type': 'number', 'default': 3.14}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == ' = 3.14'

    def test_sql_default_value(self, reset_global_state):
        """Test x-sql-default-value (pre-quoted)."""
        schema = {'type': 'string', 'x-sql-default-value': "NOW()"}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == ' = NOW()'

    def test_sql_default_value_with_quotes(self, reset_global_state):
        """Test x-sql-default-value with string literal."""
        schema = {'type': 'string', 'x-sql-default-value': "'2000-01-01'"}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == " = '2000-01-01'"

    def test_no_default(self, reset_global_state):
        """Test no default value."""
        schema = {'type': 'string'}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == ''

    def test_custom_sql_datatype_int_no_quoting(self, reset_global_state):
        """Test that x-sql-datatype INT doesn't get quoted."""
        schema = {'x-sql-datatype': 'INT', 'default': 0}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == ' = 0'

    def test_custom_sql_datatype_float_no_quoting(self, reset_global_state):
        """Test that x-sql-datatype FLOAT doesn't get quoted."""
        schema = {'x-sql-datatype': 'FLOAT', 'default': 0.0}
        result = process_openapi.generate_default_value_string_from_schema(schema)
        assert result == ' = 0.0'


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
