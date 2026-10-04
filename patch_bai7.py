import re

file_path = 'lib/services/bai_assistant.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Update futureSignals regex
old_regex = r"final futureSignals = RegExp\(r'\(will have\|will receive\|will get\|will be\|am getting\|expecting\|incoming\|due\|coming on\|need to pay\|have to pay\)'\);"
new_regex = r"final futureSignals = RegExp(r'(will have|will receive|will get|will be|am getting|expecting|incoming|due|coming on|need to pay|have to pay|on \d+|this \w+|by \d+|remind me|i have)', caseSensitive: false);"

content = content.replace(old_regex, new_regex)

with open(file_path, 'w') as f:
    f.write(content)
print("Updated future signals regex successfully!")
