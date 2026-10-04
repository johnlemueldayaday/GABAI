import re

file_path = 'lib/services/bai_assistant.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Update futureSignals regex using re.sub for safety against backslashes
pattern = r"final futureSignals = RegExp\([^)]+\);"
replacement = r"final futureSignals = RegExp(r'(will have|will receive|will get|will be|am getting|expecting|incoming|due|coming on|need to pay|have to pay|on \d+|this \w+|by \d+|remind me|i have)', caseSensitive: false);"

new_content = re.sub(pattern, replacement, content, count=1)

with open(file_path, 'w') as f:
    f.write(new_content)
print("Updated future signals regex successfully using regex!")
