import re

file_path = 'lib/services/bai_assistant.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Add new BaiSteps if they don't exist
if 'awaitingExpenseAmount' not in content:
    steps_to_add = """  awaitingExpenseAmount,
  awaitingExpenseItem,
  awaitingAllocationPeriod,
  awaitingAllocationAmount,
  awaitingClarification,"""
    content = re.sub(
        r'(enum BaiStep {.*?)(})', 
        r'\1' + steps_to_add + r'\n\2', 
        content, 
        flags=re.DOTALL
    )

# Replace the state variables block
state_vars = """
  // Track pending expense details
  double? _pendingExpenseAmount;
  String? _pendingExpenseDescription;
  String? _pendingExpenseCategory;
  Account? _pendingExpenseAccount;

  // Track pending allocation details
  String? _pendingAllocationPeriod;
  double? _pendingAllocationAmount;

  // Clarification
  String? _unclearRawInput;
"""

content = re.sub(
    r'  // Track pending expense details when waiting for account\n.*?String\? _pendingExpenseCategory;',
    state_vars,
    content,
    flags=re.DOTALL
)

with open(file_path, 'w') as f:
    f.write(content)
print("Updated states successfully.")
