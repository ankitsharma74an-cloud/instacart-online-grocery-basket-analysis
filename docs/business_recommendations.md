# Business Recommendations

## 1. Purpose

This document translates the validated analytical findings into business-oriented recommendations.

Recommendations are limited to insights directly supported by the available Instacart data.

The dataset does not provide revenue, profit, demographics, inventory, or confirmed churn information. Therefore, recommendations do not make unsupported claims in these areas.

---

# 2. Replenishment and Reorder Engagement

## Finding

The overall PRIOR reorder rate is:

**58.97%**

This indicates substantial repeat-purchase behaviour within the historical dataset.

## Recommendation

Use reorder-oriented customer experiences such as:

- Reorder shortcuts
- Previous-purchase reminders
- Personalised repeat-item recommendations
- Simplified repeat baskets

## Suggested KPIs

- Reorder rate
- Repeat-order rate
- Orders per customer
- Repeat-item engagement

## Interpretation

This recommendation focuses on facilitating repeat purchasing.

It should **not** be described as churn prevention because the dataset does not establish confirmed customer churn.

---

# 3. High-Frequency / High-Reorder Customers

## Finding

The validated behavioural segmentation identifies:

**49,610 customers**

representing approximately:

**24.06% of PRIOR customers**

within the project's high-frequency/high-reorder segment.

## Recommendation

Consider targeted retention and personalisation strategies such as:

- Personalised reorder shortcuts
- Frequently purchased item recommendations
- Repeat-basket assistance
- Loyalty-oriented experiences

## Suggested KPIs

- Orders per customer
- Reorder rate
- Repeat-purchase frequency
- Engagement with reorder recommendations

---

# 4. Department Performance

## Finding

The highest-volume departments provide important signals for assortment and replenishment priorities.

Validated examples include:

### Produce

**9,479,291 purchases**

### Dairy Eggs

**5,414,016 purchases**

### Dairy Eggs Reorder Rate

**67.00%**

## Recommendation

Prioritise high-volume/high-reorder departments for:

- Assortment attention
- Availability monitoring
- Replenishment planning
- Merchandising analysis
- Repeat-purchase experience

## Suggested KPIs

- Purchase volume
- Reorder rate
- Product-level contribution
- Department-level repeat behaviour

## Important Limitation

The dataset does not contain inventory or stockout information.

Therefore, this analysis does **not** claim that high demand caused stockouts or that any specific department experienced inventory shortages.

---

# 5. Market Basket Opportunity

## Finding

The strongest validated observed product association in the controlled market basket analysis is:

**Sparkling Lemon Water + Lime Sparkling Water**

Validated metrics:

- Orders containing both: **8,546**
- Lift: **18.0024**

## Recommendation

The association can be tested through:

- Cart recommendations
- Complementary-product suggestions
- Product placement
- Bundle experiments
- Cross-sell recommendations

## Suggested KPIs

- Pair attach rate
- Recommendation conversion
- Co-purchase rate
- Incremental basket size

## Important Limitation

A high association or lift does not prove that one product causes customers to purchase the other.

Business teams should test recommendations experimentally before assuming causal impact.

---

# 6. Product-Level Opportunity

Product-level performance analysis can be used to identify products with:

- High purchase volume
- High reorder rates
- Strong basket associations

These products can support:

- Reorder recommendations
- Personalised product suggestions
- Complementary-item discovery
- Assortment prioritisation

Recommendations should be based on observed purchasing behaviour rather than assumed customer preferences.

---

# 7. Customer Experience Opportunity

Customer behaviour analysis can support differentiated experiences.

Potential segments include customers characterised by:

- Higher order frequency
- Lower order frequency
- Higher reorder behaviour
- Lower reorder behaviour

The project uses behavioural segmentation rather than demographic segmentation because demographic information is not available in the dataset.

---

# 8. Order Timing Opportunity

The order-by-day and order-by-hour analysis can help identify recurring demand patterns.

Potential applications include:

- Campaign timing
- Customer messaging timing
- Reorder reminders
- Operational planning

These findings describe historical ordering patterns and should not be interpreted as direct inventory or staffing requirements without additional operational data.

---

# 9. Recommended Business Action Framework

| Priority | Action | KPI |
|---|---|---|
| 1 | Improve reorder experience | Reorder rate |
| 2 | Personalize high-frequency/high-reorder customers | Orders/customer + reorder rate |
| 3 | Prioritize high-volume departments | Purchase volume + reorder rate |
| 4 | Test complementary-product recommendations | Pair attach rate + conversion |
| 5 | Use order timing for customer engagement | Orders by day/hour |

---

# 10. Measurement Approach

Recommendations should be evaluated using measurable outcomes.

For recommendation experiments:

```text
Baseline
   ↓
Recommendation / Intervention
   ↓
Measure Customer Response
   ↓
Compare Against Baseline
   ↓
Evaluate Incremental Impact
```

---

# 11. Business Limitations

The following conclusions are intentionally excluded:

- Revenue optimisation claims
- Profit optimisation claims
- Customer demographic targeting
- Confirmed churn prevention
- Inventory stockout claims
- Causal claims from market basket association

These would require additional data or controlled experimentation.

---

# 12. Final Recommendation

The strongest evidence-supported opportunities from this project are:

1. Facilitate repeat purchasing through reorder experiences.
2. Prioritise high-frequency/high-reorder customers for personalisation.
3. Focus analytical attention on high-volume and high-reorder departments.
4. Test product-pair recommendations using validated basket associations.
5. Use observed order timing to improve customer engagement timing.

These recommendations are derived from the validated analytical outputs and are intentionally constrained to what the available dataset can support.
