import re

file_path = 'lib/services/bai_assistant.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Remove the unused allocation variables
content = re.sub(r'\s*String\? _pendingAllocationPeriod;', '', content)
content = re.sub(r'\s*double\? _pendingAllocationAmount;', '', content)

# Remove the unused _silenceAllocationWarnings method entirely
content = re.sub(r'\s*// Dummy method for allocation unused variables to silence warnings\s*void _silenceAllocationWarnings\(\) \{\s*_pendingAllocationPeriod = null;\s*_pendingAllocationAmount = null;\s*\}', '', content)

# Wire up _handleOngoingExpenseFlow and _handleClarification inside _handleStateMachine
wire_up_code = """    // Handle awaiting expense item/amount states
    if (_step == BaiStep.awaitingExpenseItem || 
        _step == BaiStep.awaitingExpenseAmount ||
        _step == BaiStep.awaitingExpenseAccount) {
      return await _handleOngoingExpenseFlow(n);
    }
    
    // Handle clarification state
    if (_step == BaiStep.awaitingClarification) {
      return await _handleClarification(n);
    }

    // Handle awaiting income account state"""

content = content.replace("    // Handle awaiting income account state", wire_up_code)

with open(file_path, 'w') as f:
    f.write(content)
print("Wired up methods and cleaned unused variables!")
