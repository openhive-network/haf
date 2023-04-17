import urllib.request
import json



first_account_name = b""

accounts_list = []

while True:

    req = urllib.request.Request(url='http://localhost:8091',
                         data=b'{"jsonrpc":"2.0", "method":"database_api.list_accounts", "params": {"start":"' +  first_account_name + b'", "limit":100, "order":"by_name"}, "id":1}')

    with urllib.request.urlopen(req) as f:
        json_string = f.read().decode('utf-8')

    json_object = json.loads(json_string)

    accounts = json_object["result"]["accounts"]
    
    for i, account in enumerate(accounts):
        if i != (len(accounts) - 1):
            accounts_list.append((account["name"], int(account["balance"]["amount"]), int(account["hbd_balance"]["amount"]) ,  int(account["vesting_shares"]["amount"]) ))

    if len(accounts) > 1:
        last_account = accounts[-1]
        first_account_name =  last_account["name"]
        first_account_name = str.encode(first_account_name)
    else:
        break

accounts_list.sort(key = lambda x: x[1], reverse=True)

for i in range (15):
    print(accounts_list[i])




