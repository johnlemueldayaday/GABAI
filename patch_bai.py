import re

file_path = 'lib/services/bai_assistant.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Add new BaiSteps
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

# Add state variables
state_vars = """
  // New State variables for Expense and Allocation
  String? _pendingAllocationPeriod;
  double? _pendingAllocationAmount;
  bool _isAwaitingClarification = false;
"""
content = re.sub(
    r'(double\? _pendingExpenseAmount;)', 
    state_vars + r'\1', 
    content
)

# Save changes
with open(file_path, 'w') as f:
    f.write(content)

print("Patch partially applied. A full rule-based implementation of this complex flow requires ~500 lines of custom Dart parsing logic.")
