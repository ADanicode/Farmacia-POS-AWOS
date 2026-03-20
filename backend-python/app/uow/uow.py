class UnitOfWork:

    def __init__(self, db):
        self.db = db

    def __enter__(self):
        return self

    def commit(self):
        self.db.commit()

    def rollback(self):
        self.db.rollback()

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type:
            self.rollback()
        else:
            self.commit()