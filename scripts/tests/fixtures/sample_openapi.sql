-- Test fixture: Simple enum type
/** openapi:components:schemas
test_app.asset_type:
  type: string
  enum:
    - all
    - token
    - nft
 */

-- Test fixture: Object type
/** openapi:components:schemas
test_app.account_info:
  type: object
  properties:
    account_name:
      type: string
    balance:
      type: integer
    created_at:
      type: string
      format: date-time
 */

-- Test fixture: Simple endpoint without path parameters
/** openapi:paths
/test-api/accounts:
  get:
    tags:
      - Test
    summary: Get all accounts
    operationId: test_endpoints.get_accounts
    responses:
      '200':
        description: List of accounts
        content:
          application/json:
            schema:
              type: array
              items:
                $ref: '#/components/schemas/test_app.account_info'
 */

-- Test fixture: Endpoint with path parameter
/** openapi:paths
/test-api/accounts/{account_name}:
  get:
    tags:
      - Test
    summary: Get account by name
    operationId: test_endpoints.get_account_by_name
    parameters:
      - in: path
        name: account_name
        required: true
        schema:
          type: string
    responses:
      '200':
        description: Account details
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/test_app.account_info'
 */

-- Test fixture: Endpoint with multiple path parameters
/** openapi:paths
/test-api/accounts/{account_name}/tokens/{token_id}:
  get:
    tags:
      - Test
    summary: Get specific token for account
    operationId: test_endpoints.get_account_token
    parameters:
      - in: path
        name: account_name
        required: true
        schema:
          type: string
      - in: path
        name: token_id
        required: true
        schema:
          type: integer
    responses:
      '200':
        description: Token details
        content:
          application/json:
            schema:
              type: object
              properties:
                id:
                  type: integer
                name:
                  type: string
 */

-- Test fixture: Endpoint with path-filter parameter
/** openapi:paths
/test-api/operations:
  get:
    tags:
      - Test
    summary: Get operations with path filter
    operationId: test_endpoints.get_operations
    parameters:
      - in: query
        name: path-filter
        required: false
        schema:
          type: string
      - in: query
        name: limit
        required: false
        schema:
          type: integer
          default: 100
    responses:
      '200':
        description: List of operations
        content:
          application/json:
            schema:
              type: array
              items:
                type: object
 */

-- Test fixture: Internal endpoint (should be in rewrite rules but not in openapi spec)
/** openapi:paths
/test-api/internal/debug:
  get:
    tags:
      - Internal
    summary: Internal debug endpoint
    operationId: test_endpoints.internal_debug
    x-internal: true
    responses:
      '200':
        description: Debug info
        content:
          application/json:
            schema:
              type: object
 */

-- Test fixture: Endpoint with query parameters and defaults
/** openapi:paths
/test-api/balances:
  get:
    tags:
      - Test
    summary: Get balances
    operationId: test_endpoints.get_balances
    parameters:
      - in: query
        name: user
        required: true
        schema:
          type: string
      - in: query
        name: asset-num
        required: false
        schema:
          type: integer
          x-sql-datatype: BIGINT
          default: NULL
      - in: query
        name: page
        required: false
        schema:
          type: integer
          minimum: 1
          default: 1
      - in: query
        name: page-size
        required: false
        schema:
          type: integer
          default: 100
    responses:
      '200':
        description: List of balances
        content:
          application/json:
            schema:
              type: array
              items:
                type: object
 */

-- openapi-spec
