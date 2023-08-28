# Test
input_string = '"Head: ", _head->get_block_num(), _head->get_block_id(), _head->get_block_timestamp()'
input_string = 'WLOG: , csp_expected_block, from, to'

def transform_input(input_string):
    # Splitting the input string based on commas
    parts = [part.strip() for part in input_string.split(",")]

    if not parts:
        return input_string

    # Using the first part as the prefix
    prefix = parts[0]

    # The rest of the parts are assumed to be method calls
    method_calls = parts[1:]

    # Construct the format string and the list of replacements
    format_parts = [prefix]
    replacements = []

    for idx, method_call in enumerate(method_calls, start=1):
        var_name = f"var{idx}"
        format_parts.append(f"{method_call}=${{{var_name}}}")
        replacements.append(f'("{var_name}", {method_call})')

    format_string = " ".join(format_parts)
    replacement_string = "".join(replacements)

    return f'wlog("{format_string}", {replacement_string});'

print(transform_input(input_string))
