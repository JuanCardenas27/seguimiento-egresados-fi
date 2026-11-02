class EgresadosRouter:
    """Envía los modelos de la app `egresados` a MariaDB y el resto a SQLite."""

    app_label = "egresados"
    db_alias = "egresados"

    def db_for_read(self, model, **hints):
        return self.db_alias if model._meta.app_label == self.app_label else None

    def db_for_write(self, model, **hints):
        return self.db_alias if model._meta.app_label == self.app_label else None

    def allow_relation(self, obj1, obj2, **hints):
        labels = {obj1._meta.app_label, obj2._meta.app_label}
        if labels == {self.app_label}:
            return True
        return None

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        if db == self.db_alias or app_label == self.app_label:
            return False
        return None
