import subprocess
import sys

# Install required packages
print("Installing required packages...")
subprocess.check_call([sys.executable, "-m", "pip", "install", "pandas", "pymysql", "sqlalchemy", "--quiet"])

import pandas as pd
from sqlalchemy import create_engine
import urllib.parse
import os

# ── MySQL Connection ──────────────────────────────────────────────
password = urllib.parse.quote_plus("Dream@2025")
engine = create_engine(f"mysql+pymysql://root:{password}@localhost/cms_hospital")
print("✅ Connected to MySQL\n")

# ── Helper Functions ──────────────────────────────────────────────
def clean_columns(df):
    """Clean column names: lowercase, underscores, no special chars"""
    df.columns = (df.columns
                  .str.strip()
                  .str.lower()
                  .str.replace(r'[^a-z0-9_]', '_', regex=True)
                  .str.replace(r'_+', '_', regex=True)
                  .str.strip('_'))
    return df

def load_csv(path):
    """Load CSV with encoding fallback"""
    try:
        df = pd.read_csv(path, encoding='utf-8', dtype=str, low_memory=False)
    except UnicodeDecodeError:
        df = pd.read_csv(path, encoding='latin-1', dtype=str, low_memory=False)
    return df

# ── File Paths ────────────────────────────────────────────────────
base_path = os.path.expanduser("~/Cowork Session/")

files = {
    'hospital_info':        'Hospital_General_Information.csv',
}

expected_rows = {
    'hospital_info':        5432,
}

# ── Load Each File ────────────────────────────────────────────────
for table_name, filename in files.items():
    filepath = os.path.join(base_path, filename)

    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        continue

    print(f"Loading {filename}...")
    df = load_csv(filepath)
    df = clean_columns(df)

    # Replace 'Not Available' with None (NULL in MySQL)
    df = df.replace('Not Available', None)
    df = df.replace('Not Applicable', None)

    print(f"   Rows: {len(df):,}  |  Columns: {len(df.columns)}")

    # Load into MySQL (replace if table already exists)
    df.to_sql(
        name=table_name,
        con=engine,
        if_exists='replace',
        index=False,
        chunksize=5000,
        method='multi'
    )

    actual = len(df)
    expected = expected_rows[table_name]
    status = "✅" if actual == expected else f"⚠️  expected {expected:,}"
    print(f"   {status} {table_name} loaded — {actual:,} rows\n")

print("=" * 50)
print("All done! Verify in MySQL with:")
print("  SELECT COUNT(*) FROM hospital_info;")
print("  SELECT COUNT(*) FROM complications_deaths;")
print("  SELECT COUNT(*) FROM hcahps;")
