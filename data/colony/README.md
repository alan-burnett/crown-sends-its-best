# data/colony/

What a town needs, and how much of it it keeps back.

**Reserve sizing is data, not a magic number in code** (#44). A town covers its
needs, keeps a reserve against the months ahead, and only then has anything
spare to sell.

| Field | Meaning |
| :--- | :--- |
| `per_head` | Consumed per head of population each month. Absence of these threatens survival, which is what makes them **needs** rather than wants |
| `reserve_months` | Months of need held back before anything is sold, per resource |
| `default_reserve_months` | For everything not named above |
