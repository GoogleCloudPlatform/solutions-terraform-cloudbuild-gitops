resource "google_bigquery_dataset" "cap_bank" {
  dataset_id                  = "bank"
  friendly_name               = "bank"
  description                 = "Dataset for Cap Bank"
  location                    = "EU"

}

resource "google_bigquery_table" "cap_bank_countries" {
  dataset_id = google_bigquery_dataset.cap_bank.dataset_id
  table_id   = "countries"

  schema = <<EOF
[
  {
    "name": "id",
    "type": "NUMERIC",
    "mode": "NULLABLE",
    "description": "Country ID"
  },
  {
    "name": "countryCode",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Country Code"
  },
  {
    "name": "countryName",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Country Name"
  }
]
EOF

}

resource "google_bigquery_table" "cap_bank_monthly_payments" {
  dataset_id = google_bigquery_dataset.cap_bank.dataset_id
  table_id   = "monthly_payments"

  schema = <<EOF
[
  {
    "name": "cc_number_id",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "CC ID"
  },
  {
    "name": "monthly_payment_amout",
    "type": "NUMERIC",
    "mode": "NULLABLE",
    "description": "Monthly Payment Amount"
  },
  {
    "name": "has_due_payments",
    "type": "BOOLEAN",
    "mode": "NULLABLE",
    "description": "Has due payments"
  }
]
EOF

}

resource "google_bigquery_table" "cap_bank_operations" {
  dataset_id = google_bigquery_dataset.cap_bank.dataset_id
  table_id   = "operations"

  schema = <<EOF
[
  {
    "name": "id",
    "type": "NUMERIC",
    "mode": "NULLABLE",
    "description": "Operation ID"
  },
  {
    "name": "operationCode",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Operation Code"
  },
  {
    "name": "operationType",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Operation Type"
  }
]
EOF

}

resource "google_bigquery_table" "cap_bank_payments" {
  dataset_id = google_bigquery_dataset.cap_bank.dataset_id
  table_id   = "payments"

  schema = <<EOF
[
  {
    "name": "id",
    "type": "NUMERIC",
    "mode": "NULLABLE",
    "description": "Payment ID"
  },
  {
    "name": "paymentCode",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Payment Code"
  },
  {
    "name": "paymentType",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Payment Type"
  }
]
EOF

}

resource "google_bigquery_table" "cap_bank_transactions" {
  dataset_id = google_bigquery_dataset.cap_bank.dataset_id
  table_id   = "transactions"

  schema = <<EOF
[
  {
    "name": "id",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Transaction ID"
  },
  {
    "name": "quantity",
    "type": "NUMERIC",
    "mode": "NULLABLE",
    "description": "Quantity"
  },
  {
    "name": "amount",
    "type": "NUMERIC",
    "mode": "NULLABLE",
    "description": "Amount"
  },
  {
    "name": "countryCode",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Country Code"
  },
  {
    "name": "operationCode",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Operation Code"
  },
  {
    "name": "paymentType",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Payment Type"
  },
  {
    "name": "transDate",
    "type": "DATE",
    "mode": "NULLABLE",
    "description": "Transaction Date"
  }
]
EOF

}

resource "google_bigquery_table" "cap_bank_trans_main" {
  dataset_id = google_bigquery_dataset.cap_bank.dataset_id
  table_id   = "transactions"

  view {
    query = <<SQL
select t.id as ID, 
  t.quantity as Quantity, 
  t.amount as Amount, 
  c.countryName as Country, 
  o.operationType as Operation, 
  p.paymentType as PaymentType, 
  t.transDate as TransactionDate 
from bank.transactions t
inner join bank.countries c on c.countryCode = t.countryCode
inner join bank.operations o on o.operationCode = t.operationCode
left join bank.payments p on p.paymentCode = t.paymentType
SQL
    use_legacy_sql = false
  }

}