import re

file_path = 'lib/services/bai_assistant.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Remove unnecessary braces from string interpolations
content = content.replace('${_pendingScheduledName}', '$_pendingScheduledName')
content = content.replace('${_pendingScheduledDate}', '$_pendingScheduledDate')
# Note: ${_pendingScheduledAmount!.toStringAsFixed(2)} is fine and necessary, so it won't be replaced.

with open(file_path, 'w') as f:
    f.write(content)
print("Removed unnecessary braces!")
