def value_change_handler(iface, prop_changed, prop_removed):
    if 'Value' in prop_changed:
        print(f"Value: {prop_changed['Value']}")
    if 'Value' in prop_removed:
        print("Value removed")
    if 'Value' not in prop_changed and 'Value' not in prop_removed:
        print("Value unchanged")
    
        