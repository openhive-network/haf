#!/usr/bin/env python
"""
Tests for OpenAPI fragment merging behavior.

Tests:
- Merging component schemas
- Merging path definitions
- List override behavior (prevents enum duplication bug)
- Internal endpoint filtering
"""

import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(SCRIPTS_DIR))

import process_openapi


class TestMergeComponents:
    """Test merging of OpenAPI component schemas."""

    def test_merge_components(self, reset_global_state):
        """Test merging component schemas."""
        fragment1 = {'components': {'schemas': {'Type1': {'type': 'string'}}}}
        fragment2 = {'components': {'schemas': {'Type2': {'type': 'integer'}}}}
        
        process_openapi.merge_openapi_fragment(fragment1)
        process_openapi.merge_openapi_fragment(fragment2)
        
        assert 'Type1' in process_openapi.collected_openapi_fragments['components']['schemas']
        assert 'Type2' in process_openapi.collected_openapi_fragments['components']['schemas']

    def test_merge_same_component_overwrites(self, reset_global_state):
        """Test that merging the same component overwrites the previous one."""
        fragment1 = {'components': {'schemas': {'MyType': {'type': 'string', 'description': 'first'}}}}
        fragment2 = {'components': {'schemas': {'MyType': {'type': 'string', 'description': 'second'}}}}
        
        process_openapi.merge_openapi_fragment(fragment1)
        process_openapi.merge_openapi_fragment(fragment2)
        
        assert process_openapi.collected_openapi_fragments['components']['schemas']['MyType']['description'] == 'second'


class TestMergePaths:
    """Test merging of OpenAPI path definitions."""

    def test_merge_paths(self, reset_global_state):
        """Test merging path definitions."""
        fragment1 = {
            'paths': {
                '/api/endpoint1': {
                    'get': {
                        'operationId': 'get_endpoint1',
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        fragment2 = {
            'paths': {
                '/api/endpoint2': {
                    'get': {
                        'operationId': 'get_endpoint2',
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        
        process_openapi.merge_openapi_fragment(fragment1)
        process_openapi.merge_openapi_fragment(fragment2)
        
        assert '/api/endpoint1' in process_openapi.collected_openapi_fragments['paths']
        assert '/api/endpoint2' in process_openapi.collected_openapi_fragments['paths']

    def test_merge_methods_on_same_path(self, reset_global_state):
        """Test merging different methods on the same path."""
        fragment1 = {
            'paths': {
                '/api/resource': {
                    'get': {
                        'operationId': 'get_resource',
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        fragment2 = {
            'paths': {
                '/api/resource': {
                    'post': {
                        'operationId': 'create_resource',
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        
        process_openapi.merge_openapi_fragment(fragment1)
        process_openapi.merge_openapi_fragment(fragment2)
        
        assert 'get' in process_openapi.collected_openapi_fragments['paths']['/api/resource']
        assert 'post' in process_openapi.collected_openapi_fragments['paths']['/api/resource']


class TestEnumDeduplication:
    """
    Test that enum values are NOT duplicated during merge.
    
    This tests the fix for a bug where merging the same enum twice would result in:
        - all
        - token
        - nft
        - all
        - token
        - nft
    
    Instead of:
        - all
        - token
        - nft
    """

    def test_list_override_behavior(self, reset_global_state):
        """Test that lists are overridden (not appended) during merge."""
        fragment1 = {
            'components': {
                'schemas': {
                    'MyEnum': {
                        'type': 'string',
                        'enum': ['value1', 'value2']
                    }
                }
            }
        }
        fragment2 = {
            'components': {
                'schemas': {
                    'MyEnum': {
                        'type': 'string',
                        'enum': ['value3', 'value4']
                    }
                }
            }
        }
        
        process_openapi.merge_openapi_fragment(fragment1)
        process_openapi.merge_openapi_fragment(fragment2)
        
        # The second enum should override the first, not append
        enum_values = process_openapi.collected_openapi_fragments['components']['schemas']['MyEnum']['enum']
        assert enum_values == ['value3', 'value4']
        assert 'value1' not in enum_values
        assert 'value2' not in enum_values

    def test_enum_not_duplicated_on_same_merge(self, reset_global_state):
        """Test that merging the same enum twice doesn't duplicate values."""
        fragment = {
            'components': {
                'schemas': {
                    'asset_type': {
                        'type': 'string',
                        'enum': ['all', 'token', 'nft']
                    }
                }
            }
        }
        
        # Merge the same fragment twice (simulating processing the same file twice)
        process_openapi.merge_openapi_fragment(fragment)
        process_openapi.merge_openapi_fragment(fragment)
        
        enum_values = process_openapi.collected_openapi_fragments['components']['schemas']['asset_type']['enum']
        
        # Should NOT have duplicated values like ['all', 'token', 'nft', 'all', 'token', 'nft']
        assert enum_values == ['all', 'token', 'nft']
        assert len(enum_values) == 3
        
        # Explicitly check no duplicates
        assert enum_values.count('all') == 1
        assert enum_values.count('token') == 1
        assert enum_values.count('nft') == 1

    def test_enum_not_duplicated_three_merges(self, reset_global_state):
        """Test that merging the same enum three times doesn't duplicate values."""
        fragment = {
            'components': {
                'schemas': {
                    'direction': {
                        'type': 'string',
                        'enum': ['asc', 'desc']
                    }
                }
            }
        }
        
        # Merge the same fragment three times
        process_openapi.merge_openapi_fragment(fragment)
        process_openapi.merge_openapi_fragment(fragment)
        process_openapi.merge_openapi_fragment(fragment)
        
        enum_values = process_openapi.collected_openapi_fragments['components']['schemas']['direction']['enum']
        
        assert enum_values == ['asc', 'desc']
        assert len(enum_values) == 2

    def test_oneof_array_not_duplicated(self, reset_global_state):
        """Test that oneOf arrays are not duplicated during merge."""
        fragment = {
            'components': {
                'schemas': {
                    'response': {
                        'oneOf': [
                            {'$ref': '#/components/schemas/TypeA'},
                            {'$ref': '#/components/schemas/TypeB'}
                        ]
                    }
                }
            }
        }
        
        process_openapi.merge_openapi_fragment(fragment)
        process_openapi.merge_openapi_fragment(fragment)
        
        oneof_values = process_openapi.collected_openapi_fragments['components']['schemas']['response']['oneOf']
        
        assert len(oneof_values) == 2
        assert oneof_values[0] == {'$ref': '#/components/schemas/TypeA'}
        assert oneof_values[1] == {'$ref': '#/components/schemas/TypeB'}

    def test_parameters_array_not_duplicated(self, reset_global_state):
        """Test that parameters arrays are not duplicated during merge."""
        fragment = {
            'paths': {
                '/api/test': {
                    'get': {
                        'operationId': 'test_endpoint',
                        'parameters': [
                            {'name': 'page', 'in': 'query', 'schema': {'type': 'integer'}},
                            {'name': 'limit', 'in': 'query', 'schema': {'type': 'integer'}}
                        ],
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        
        process_openapi.merge_openapi_fragment(fragment)
        process_openapi.merge_openapi_fragment(fragment)
        
        params = process_openapi.collected_openapi_fragments['paths']['/api/test']['get']['parameters']
        
        assert len(params) == 2
        param_names = [p['name'] for p in params]
        assert param_names == ['page', 'limit']


class TestInternalEndpointFiltering:
    """Test filtering of internal endpoints from public OpenAPI spec."""

    def test_internal_only_fragment_not_added(self, reset_global_state):
        """Test that a fragment with only internal paths is not added to public spec."""
        fragment = {
            'paths': {
                '/api/internal/debug': {
                    'get': {
                        'operationId': 'debug',
                        'x-internal': True,
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        
        process_openapi.merge_openapi_fragment(fragment)
        
        # Internal path should not be in public spec
        assert 'paths' not in process_openapi.collected_openapi_fragments or \
               '/api/internal/debug' not in process_openapi.collected_openapi_fragments.get('paths', {})
        
        # But should be in all_openapi_fragments for rewrite rules
        assert '/api/internal/debug' in process_openapi.all_openapi_fragments['paths']

    def test_mixed_internal_and_public_paths(self, reset_global_state):
        """Test fragment with both internal and public paths."""
        fragment = {
            'paths': {
                '/api/public': {
                    'get': {
                        'operationId': 'public_endpoint',
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                },
                '/api/internal': {
                    'get': {
                        'operationId': 'internal_endpoint',
                        'x-internal': True,
                        'responses': {'200': {'description': 'OK', 'content': {'application/json': {'schema': {'type': 'object'}}}}}
                    }
                }
            }
        }
        
        process_openapi.merge_openapi_fragment(fragment)
        
        # Public path should be in collected_openapi_fragments
        assert '/api/public' in process_openapi.collected_openapi_fragments['paths']
        # Internal path should NOT be in collected_openapi_fragments
        assert '/api/internal' not in process_openapi.collected_openapi_fragments['paths']
        
        # Both should be in all_openapi_fragments
        assert '/api/public' in process_openapi.all_openapi_fragments['paths']
        assert '/api/internal' in process_openapi.all_openapi_fragments['paths']


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
