#!/usr/bin/env python


import sys
import psycopg2
import psycopg2.extras


class SqlExportView():

    def __init__(self, pg_service, definition):
        self.conn = psycopg2.connect("service={0}".format(pg_service))
        self.cur = self.conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        self.definition = definition

    def get_columns(self, table, exclude_fields=[]):
        exclude_fields_sql = ''.join(
            [" AND attname NOT LIKE '{0}'".format(col) for col in exclude_fields])
        sql = "SELECT attname FROM pg_attribute WHERE attrelid = '{0}'::regclass AND attisdropped IS NOT TRUE AND attnum > 0 {1} ORDER BY attnum ASC".format(
            table, exclude_fields_sql)
        self.cur.execute(sql)
        pg_fields = self.cur.fetchall()
        pg_fields = [field[0] for field in pg_fields]
        return pg_fields

    def sql(self):
        exclude_join_fields = []
        if 'exclude_join_fields' in self.definition:
            exclude_join_fields = self.definition['exclude_join_fields']

        sql = """
        CREATE OR REPLACE VIEW {0} AS
            SELECT \n\t\t\t\t{1}""".format(
                self.definition['name'],
                '\n\t\t\t\t, '.join(['{0}.{1}'.format(self.definition['from'], col)
                                    for col in self.get_columns(self.definition['from'])])
                )

        for join in self.definition['joins']:
            table_exclude_fields = exclude_join_fields
            table_exclude_fields.append(self.definition['joins'][join]['key'])
            columns = self.get_columns(self.definition['joins'][join]['table'], table_exclude_fields)
            sql += ''.join(['\n\t\t\t\t, {0}.{1} AS {0}_{1}'.format(join, col) for col in columns])

        sql += "\n\t\t\tFROM {0}".format(self.definition['from'])

        for join in self.definition['joins']:
            sql += "\n\t\t\t\tLEFT JOIN {0} {1} ON {2}.{3} = {1}.{4}".format(
                self.definition['joins'][join]['table'],
                join,
                self.definition['from'],
                self.definition['joins'][join]['fkey'],
                self.definition['joins'][join]['key']
                )

        return sql
