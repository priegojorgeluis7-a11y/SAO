from main import Base, engine

Base.metadata.create_all(bind=engine)
print("schema_ok")
