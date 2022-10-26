import json

value_counter = 0
records_counter = 0

with open("source_zone.json") as source_zone:
    source_json = json.loads(source_zone.read())
result = {
    "Changes": [],   
}
for record_set in source_json["ResourceRecordSets"]:
    if record_set.get("Type") in ["NS", "SOA"]:
        continue
    for record in record_set.get("ResourceRecords", []):
        value_counter += len(record["Value"])
        records_counter += 1

    result['Changes'].append({
        "Action": "CREATE",
        "ResourceRecordSet": record_set,
    })
# print to error stream
if records_counter > 1000:
    print("Too many records: {}".format(records_counter), file=sys.stderr)
    sys.exit(1)
if value_counter > 32000:
    print("Too many characters: {}".format(value_counter), file=sys.stderr)
    sys.exit(1)

print(json.dumps(result, indent=4))
