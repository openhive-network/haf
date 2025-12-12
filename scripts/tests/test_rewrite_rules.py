#!/usr/bin/env python
"""
Tests for nginx rewrite rule generation from OpenAPI paths.

Tests various scenarios:
- Simple paths without parameters
- Paths with single/multiple path parameters
- Paths with path-filter query parameter
- Internal endpoints (x-internal: true)
- Home rewrite flag (--home-rewrite)
"""

import os
import re
import sys
import tempfile
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(SCRIPTS_DIR))

import process_openapi


class TestSimplePaths:
    """Test rewrite rule generation for simple paths without parameters."""

    def test_simple_path_no_params(self, reset_global_state):
        """Test rewrite rule for simple path without parameters."""
        fragment = {
            'paths': {
                '/api/accounts': {
                    'get': {
                        'operationId': 'endpoints.get_accounts',
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=False)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            assert 'rewrite ^/api/accounts /rpc/get_accounts break;' in content
            assert 'rewrite ^/(.*)$ /rpc/$1 break;' in content
        finally:
            os.unlink(temp_file)


class TestPathParameters:
    """Test rewrite rule generation for paths with path parameters."""

    def test_path_with_single_parameter(self, reset_global_state):
        """Test rewrite rule for path with single path parameter."""
        fragment = {
            'paths': {
                '/api/accounts/{account_id}': {
                    'get': {
                        'operationId': 'endpoints.get_account',
                        'parameters': [
                            {'name': 'account_id', 'in': 'path', 'schema': {'type': 'string'}}
                        ],
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=False)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            assert 'rewrite ^/api/accounts/([^/]+) /rpc/get_account?account_id=$1 break;' in content
        finally:
            os.unlink(temp_file)

    def test_path_with_multiple_parameters(self, reset_global_state):
        """Test rewrite rule for path with multiple path parameters."""
        fragment = {
            'paths': {
                '/api/users/{user_id}/tokens/{token_id}': {
                    'get': {
                        'operationId': 'endpoints.get_user_token',
                        'parameters': [
                            {'name': 'user_id', 'in': 'path', 'schema': {'type': 'string'}},
                            {'name': 'token_id', 'in': 'path', 'schema': {'type': 'integer'}}
                        ],
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=False)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            assert 'rewrite ^/api/users/([^/]+)/tokens/([^/]+) /rpc/get_user_token?user_id=$1&token_id=$2 break;' in content
        finally:
            os.unlink(temp_file)

    def test_capture_group_pattern(self, reset_global_state):
        """Test that path parameters generate correct capture groups."""
        fragment = {
            'paths': {
                '/api/items/{item_id}': {
                    'get': {
                        'operationId': 'endpoints.get_item',
                        'parameters': [{'name': 'item_id', 'in': 'path', 'schema': {'type': 'string'}}],
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=False)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            match = re.search(r'rewrite (\^/api/items/\S+) (/rpc/\S+) break;', content)
            assert match is not None
            
            pattern = match.group(1)
            target = match.group(2)
            
            assert '([^/]+)' in pattern
            assert 'item_id=$1' in target
        finally:
            os.unlink(temp_file)

    def test_multiple_capture_groups_ordering(self, reset_global_state):
        """Test that multiple capture groups are numbered correctly."""
        fragment = {
            'paths': {
                '/api/users/{user_id}/posts/{post_id}/comments/{comment_id}': {
                    'get': {
                        'operationId': 'endpoints.get_comment',
                        'parameters': [
                            {'name': 'user_id', 'in': 'path', 'schema': {'type': 'string'}},
                            {'name': 'post_id', 'in': 'path', 'schema': {'type': 'string'}},
                            {'name': 'comment_id', 'in': 'path', 'schema': {'type': 'string'}}
                        ],
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=False)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            assert 'user_id=$1' in content
            assert 'post_id=$2' in content
            assert 'comment_id=$3' in content
        finally:
            os.unlink(temp_file)


class TestPathFilterParameter:
    """Test rewrite rule generation for paths with path-filter query parameter."""

    def test_path_with_path_filter_parameter(self, reset_global_state):
        """Test rewrite rule for path with path-filter query parameter."""
        fragment = {
            'paths': {
                '/api/operations': {
                    'get': {
                        'operationId': 'endpoints.get_operations',
                        'parameters': [
                            {'name': 'path-filter', 'in': 'query', 'schema': {'type': 'string'}}
                        ],
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=False)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            assert 'rewrite ^/api/operations /rpc/get_operations?path-filter=$path_filters break;' in content
        finally:
            os.unlink(temp_file)

    def test_path_with_param_and_path_filter(self, reset_global_state):
        """Test rewrite rule for path with both path parameter and path-filter."""
        fragment = {
            'paths': {
                '/api/accounts/{account_id}/operations': {
                    'get': {
                        'operationId': 'endpoints.get_account_operations',
                        'parameters': [
                            {'name': 'account_id', 'in': 'path', 'schema': {'type': 'string'}},
                            {'name': 'path-filter', 'in': 'query', 'schema': {'type': 'string'}}
                        ],
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=False)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            assert 'rewrite ^/api/accounts/([^/]+)/operations /rpc/get_account_operations?account_id=$1&path-filter=$path_filters break;' in content
        finally:
            os.unlink(temp_file)


class TestInternalEndpoints:
    """Test rewrite rule generation for internal endpoints (x-internal: true)."""

    def test_internal_endpoint_in_rewrite_rules(self, reset_global_state):
        """Test that internal endpoints are included in rewrite rules with comment."""
        fragment = {
            'paths': {
                '/api/internal/debug': {
                    'get': {
                        'operationId': 'endpoints.debug',
                        'x-internal': True,
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=False)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            assert '(internal)' in content
            assert 'rewrite ^/api/internal/debug /rpc/debug break;' in content
        finally:
            os.unlink(temp_file)

    def test_internal_endpoint_not_in_openapi_spec(self, reset_global_state):
        """Test that internal endpoints are NOT included in the public OpenAPI spec."""
        fragment = {
            'paths': {
                '/api/internal/debug': {
                    'get': {
                        'operationId': 'endpoints.debug',
                        'x-internal': True,
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                },
                '/api/public': {
                    'get': {
                        'operationId': 'endpoints.public',
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        # Internal endpoint should NOT be in collected_openapi_fragments (public spec)
        assert '/api/internal/debug' not in process_openapi.collected_openapi_fragments.get('paths', {})
        # Public endpoint should be in collected_openapi_fragments
        assert '/api/public' in process_openapi.collected_openapi_fragments.get('paths', {})
        
        # Both should be in all_openapi_fragments (for rewrite rules)
        assert '/api/internal/debug' in process_openapi.all_openapi_fragments.get('paths', {})
        assert '/api/public' in process_openapi.all_openapi_fragments.get('paths', {})


class TestHomeRewriteFlag:
    """Test the --home-rewrite flag behavior."""

    def test_home_rewrite_enabled(self, reset_global_state):
        """Test rewrite rules with home rewrite enabled."""
        fragment = {
            'paths': {
                '/api/test': {
                    'get': {
                        'operationId': 'endpoints.test',
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=True)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            assert 'rewrite ^/(.*)$ /rpc/home break;' in content
            assert 'rewrite ^/$ / break;' not in content
        finally:
            os.unlink(temp_file)

    def test_home_rewrite_disabled(self, reset_global_state):
        """Test rewrite rules with home rewrite disabled (default)."""
        fragment = {
            'paths': {
                '/api/test': {
                    'get': {
                        'operationId': 'endpoints.test',
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        process_openapi.merge_openapi_fragment(fragment)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as f:
            temp_file = f.name
        
        try:
            process_openapi.generate_rewrite_rules(temp_file, use_home_rewrite=False)
            with open(temp_file, 'r') as f:
                content = f.read()
            
            assert 'rewrite ^/(.*)$ /rpc/$1 break;' in content
            assert 'rewrite ^/$ / break;' in content
        finally:
            os.unlink(temp_file)


class TestFullRewriteRulesProcessing:
    """Test full SQL file processing and rewrite rule generation."""

    def test_process_sample_fixture(self, reset_global_state, fixtures_dir, tmp_path):
        """Test processing the sample fixture file and comparing rewrite rules."""
        sample_file = fixtures_dir / 'sample_openapi.sql'
        
        if not sample_file.exists():
            pytest.skip(f"Fixture file not found: {sample_file}")
        
        # First pass: collect fragments
        with open(sample_file) as f:
            process_openapi.process_sql_file(f, None)
        
        # Generate rewrite rules
        rewrite_file = tmp_path / 'rewrite_rules.conf'
        process_openapi.generate_rewrite_rules(str(rewrite_file), use_home_rewrite=False)
        
        with open(rewrite_file) as f:
            generated_content = f.read()
        
        # Verify key patterns are present
        assert 'rewrite ^/(.*)$ /rpc/$1 break;' in generated_content
        assert 'rewrite ^/$ / break;' in generated_content
        
        # Verify endpoint rewrites
        assert '/rpc/get_accounts break;' in generated_content
        assert '/rpc/get_account_by_name?account_name=$1 break;' in generated_content
        assert '/rpc/get_account_token?account_name=$1&token_id=$2 break;' in generated_content
        assert '?path-filter=$path_filters break;' in generated_content
        assert '(internal)' in generated_content

    def test_process_with_home_rewrite(self, reset_global_state, fixtures_dir, tmp_path):
        """Test processing with home rewrite flag."""
        sample_file = fixtures_dir / 'sample_openapi.sql'
        
        if not sample_file.exists():
            pytest.skip(f"Fixture file not found: {sample_file}")
        
        # First pass: collect fragments
        with open(sample_file) as f:
            process_openapi.process_sql_file(f, None)
        
        # Generate rewrite rules with home rewrite
        rewrite_file = tmp_path / 'rewrite_rules_home.conf'
        process_openapi.generate_rewrite_rules(str(rewrite_file), use_home_rewrite=True)
        
        with open(rewrite_file) as f:
            generated_content = f.read()
        
        assert 'rewrite ^/(.*)$ /rpc/home break;' in generated_content
        assert 'rewrite ^/$ / break;' not in generated_content


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
