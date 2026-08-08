import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text
import sys
import os

# Add parent dir to path so we can import app modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app.core.config import settings

async def main():
    db_url = settings.DATABASE_URL
    if not db_url:
        print("DATABASE_URL is not set. Make sure it is exported or configured.")
        return
        
    if db_url.startswith("postgresql://"):
        db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        
    print(f"Connecting to database to fetch logs...")
    engine = create_async_engine(db_url)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    try:
        async with async_session() as session:
            # Query the audit_logs table
            result = await session.execute(
                text("SELECT action, table_name, record_id, old_values, new_values FROM audit_logs LIMIT 20")
            )
            rows = result.fetchall()
            if not rows:
                print("No audit logs found in the table.")
            else:
                print("\n=== Recent Database Audit Logs ===")
                for i, row in enumerate(rows, 1):
                    print(f"\n{i}. Action: {row[0].upper()} | Table: {row[1]} | Record ID: {row[2]}")
                    print(f"   New Values: {row[4]}")
    except Exception as e:
        print(f"Error querying database: {e}")
    finally:
        await engine.dispose()

if __name__ == '__main__':
    asyncio.run(main())
