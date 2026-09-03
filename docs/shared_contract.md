# AMMA Shared Data Contract

## User

Fields:
- id
- name
- email
- role
- createdAt

Roles:
- asha
- patient

---

## Mother

Fields:
- id
- name
- age
- phone
- gestationalWeeks
- bloodPressure
- weight
- hemoglobin
- symptoms
- emergencyContact
- riskLevel
- assignedAshaId
- createdAt

---

## HealthRecord

Fields:
- id
- motherId
- date
- bloodPressure
- hemoglobin
- weight
- symptoms
- riskLevel
- matchedRules
- explanation
- recommendation
- ruleVersion

---

## Appointment

Fields:
- id
- motherId
- date
- type
- status
- reminderEnabled

---

## Alert

Fields:
- id
- motherId
- type
- riskLevel
- message
- status
- createdAt

---

## RiskResult

Fields:
- riskLevel
- matchedRules
- explanation
- recommendation
- ruleVersion
- timestamp

---

## Common Rules

IDs:
- Use `id` for the primary identifier of an entity.
- Use `motherId` when referring to a mother.
- Use `assignedAshaId` when referring to the assigned ASHA.

Timestamps:
- createdAt
- updatedAt
- recordedAt
- syncedAt

Risk levels:
- LOW
- MODERATE
- HIGH

The clinical risk engine is deterministic and must not use an LLM.