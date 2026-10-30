"""Admin write services (D2, Lane B1).

Every mutation goes through ``writer.run_write``: one transaction that locks the row, checks the
``If-Match`` version, applies the change, audits it, locks the edited fields and bumps the datasets.
"""
