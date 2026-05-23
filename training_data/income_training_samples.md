# BAI Income Training Dataset
## 30 Variations of Incoming Money Transactions

### Dataset: Income/Allowance Transactions

#### 1. Basic Salary Variations
1. **Input**: "i received 25000 salary to my bank account"
   - Amount: 25000
   - Source: Salary
   - Account: Bank Account
   - Expected Response: "💵 Income logged! +₱25,000.00 to Bank Account (Salary)"

2. **Input**: "got paid 15000 sweldo from boss to gcash"
   - Amount: 15000
   - Source: Salary/Sweldo
   - Account: GCash
   - Expected Response: "💵 Income logged! +₱15,000.00 to GCash (Salary)"

3. **Input**: "received my paycheck of 30000 to cash"
   - Amount: 30000
   - Source: Salary
   - Account: Cash
   - Expected Response: "💵 Income logged! +₱30,000.00 to Cash (Salary)"

#### 2. Family/Gift Money
4. **Input**: "mom gave me 500 pesos"
   - Amount: 500
   - Source: Gift from family
   - Account: (to be asked)
   - Expected Response: "Where did you receive it? Available accounts: [list]"

5. **Input**: "dad sent me 2000 to my gcash"
   - Amount: 2000
   - Source: Gift/Allowance
   - Account: GCash
   - Expected Response: "💵 Income logged! +₱2,000.00 to GCash (Others)"

6. **Input**: "kuya handed me 3500 cash"
   - Amount: 3500
   - Source: Gift
   - Account: Cash
   - Expected Response: "💵 Income logged! +₱3,500.00 to Cash (Others)"

7. **Input**: "lola donated 1200 to my bank"
   - Amount: 1200
   - Source: Gift/Donation
   - Account: Bank
   - Expected Response: "💵 Income logged! +₱1,200.00 to Bank (Others)"

8. **Input**: "sister paid me back 800 in cash"
   - Amount: 800
   - Source: Loan return
   - Account: Cash
   - Expected Response: "💵 Income logged! +₱800.00 to Cash (Others)"

#### 3. Freelance/Gig Work
9. **Input**: "i received 5000 from freelance project to bank"
   - Amount: 5000
   - Source: Freelance
   - Account: Bank
   - Expected Response: "💵 Income logged! +₱5,000.00 to Bank (Freelance)"

10. **Input**: "got 2500 from sideline work to gcash"
    - Amount: 2500
    - Source: Freelance/Sideline
    - Account: GCash
    - Expected Response: "💵 Income logged! +₱2,500.00 to GCash (Freelance)"

11. **Input**: "received payment 3200 for gig work in cash"
    - Amount: 3200
    - Source: Gig work
    - Account: Cash
    - Expected Response: "💵 Income logged! +₱3,200.00 to Cash (Freelance)"

12. **Input**: "freelance project paid me 7500 to my bank account"
    - Amount: 7500
    - Source: Freelance
    - Account: Bank
    - Expected Response: "💵 Income logged! +₱7,500.00 to Bank (Freelance)"

#### 4. Sales/Selling Items
13. **Input**: "sold my preloved clothes for 1500 gcash"
    - Amount: 1500
    - Source: Sale/Preloved
    - Account: GCash
    - Expected Response: "💵 Income logged! +₱1,500.00 to GCash (Others)"

14. **Input**: "i got 2800 from selling stuff on shopee to bank"
    - Amount: 2800
    - Source: Sale
    - Account: Bank
    - Expected Response: "💵 Income logged! +₱2,800.00 to Bank (Others)"

15. **Input**: "received 4200 from sale of old phone in cash"
    - Amount: 4200
    - Source: Sale
    - Account: Cash
    - Expected Response: "💵 Income logged! +₱4,200.00 to Cash (Others)"

#### 5. Refunds/Returns
16. **Input**: "got refund 950 from online store to gcash"
    - Amount: 950
    - Source: Refund
    - Account: GCash
    - Expected Response: "💵 Income logged! +₱950.00 to GCash (Others)"

17. **Input**: "i received tax refund of 8500 to my bank"
    - Amount: 8500
    - Source: Tax refund
    - Account: Bank
    - Expected Response: "💵 Income logged! +₱8,500.00 to Bank (Others)"

18. **Input**: "deposit refund 1100 cash"
    - Amount: 1100
    - Source: Refund
    - Account: Cash
    - Expected Response: "Where did you receive it? Available accounts: [list]"

#### 6. Bonuses/Extra Income
19. **Input**: "got bonus 12000 from company to bank account"
    - Amount: 12000
    - Source: Bonus
    - Account: Bank
    - Expected Response: "💵 Income logged! +₱12,000.00 to Bank (Others)"

20. **Input**: "received 5500 bonus in cash"
    - Amount: 5500
    - Source: Bonus
    - Account: Cash
    - Expected Response: "Where did you receive it? Available accounts: [list]"

#### 7. Investments/Returns
21. **Input**: "received investment dividend 3000 to my bank"
    - Amount: 3000
    - Source: Investment income
    - Account: Bank
    - Expected Response: "💵 Income logged! +₱3,000.00 to Bank (Investment)"

22. **Input**: "crypto gains 15000 to gcash"
    - Amount: 15000
    - Source: Investment
    - Account: GCash
    - Expected Response: "💵 Income logged! +₱15,000.00 to GCash (Investment)"

#### 8. Casual Phrasing
23. **Input**: "200 from mom"
    - Amount: 200
    - Source: Gift
    - Account: (to be asked)
    - Expected Response: "Where did you receive it? Available accounts: [list]"

24. **Input**: "john sent me 350 gcash"
    - Amount: 350
    - Source: Transfer/Gift
    - Account: GCash
    - Expected Response: "💵 Income logged! +₱350.00 to GCash (Others)"

25. **Input**: "mark paid me 600 in cash"
    - Amount: 600
    - Source: Payment/Return
    - Account: Cash
    - Expected Response: "💵 Income logged! +₱600.00 to Cash (Others)"

#### 9. Allowance Variations
26. **Input**: "got my allowance 3000 to my cash wallet"
    - Amount: 3000
    - Source: Allowance
    - Account: Cash
    - Expected Response: "💵 Income logged! +₱3,000.00 to Cash (Others)"

27. **Input**: "received allowance from parents 5000 to bank"
    - Amount: 5000
    - Source: Allowance
    - Account: Bank
    - Expected Response: "💵 Income logged! +₱5,000.00 to Bank (Others)"

#### 10. Ambiguous/Multi-language Mix
28. **Input**: "i received 2500 pesos from side gig to gcash"
    - Amount: 2500
    - Source: Side gig
    - Account: GCash
    - Expected Response: "💵 Income logged! +₱2,500.00 to GCash (Freelance)"

29. **Input**: "nabigyan ako ng 1800 from cousin sa cash"
    - Amount: 1800
    - Source: Gift (Tagalog phrasing)
    - Account: Cash
    - Expected Response: "💵 Income logged! +₱1,800.00 to Cash (Others)"

30. **Input**: "inflow of 4500 to my bank from consulting"
    - Amount: 4500
    - Source: Income/Consulting
    - Account: Bank
    - Expected Response: "💵 Income logged! +₱4,500.00 to Bank (Freelance)"

---

## Pattern Analysis for Training

### Detected Patterns:
1. **Strong Income Indicators**: `received`, `got paid`, `salary`, `allowance`, `sent me`, `gave me`
2. **Amount Formats**: `500`, `500 pesos`, `500 php`, `500 ₱`
3. **Account Mentions**: `bank`, `gcash`, `cash`, `maya`, `wallet`
4. **Source Keywords**: `from mom`, `salary`, `freelance`, `bonus`, `refund`
5. **Phrasing Variations**:
   - "received X from Y" → Direct statement
   - "Y gave me X" → Person-based phrasing
   - "got X for [work]" → Activity-based
   - "X inflow to account" → Formal phrasing

### Testing Edge Cases:
- **Ambiguous inputs** (e.g., "200 from mom") → Should ask for account
- **Multiple mentions** (e.g., "got 500 from gcash from friend") → Should extract correctly
- **Different amounts** (e.g., "25000", "25.50", "25k") → Should parse numbers
- **Language mix** (Tagalog + English) → Should still recognize intent

---

## Recommendation for AI Training

**Use these samples to train your model on:**

1. **Intent Classification**: Distinguish income vs. expense vs. transfer
2. **Entity Extraction**: Amount, source, account, person name
3. **Slot Filling**: When account is missing, appropriately ask the user
4. **Response Generation**: Generate natural confirmations with transaction details
5. **Category Prediction**: Auto-categorize income (Salary, Freelance, Investment, Others)

**Suggested Training Split:**
- 60% for intent recognition
- 20% for entity extraction
- 20% for edge cases & fallbacks
