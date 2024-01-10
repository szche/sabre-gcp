import sqlalchemy


connection_name = "testsabregcp:us-central1:chadam-db-sql-mysql"

#database name
db_name = "sabre"
db_user = "root"
db_password = "password"
driver_name = 'mysql+pymysql'
query_string = dict({"unix_socket": "/cloudsql/{}".format(connection_name)})

creator = sqlalchemy.text("CREATE TABLE IF NOT EXISTS info (id INT NOT NULL AUTO_INCREMENT, date DATE, hours INT, PRIMARY KEY (id));")


def writeToSql(request):
   request_json = request.get_json(silent=True)
   date = request_json["date"]
   hours = request_json["hours"]
   print(date, hours)

   stmt = sqlalchemy.text(f"INSERT INTO info ( date, hours ) values ('{date}', {hours})")

   db = sqlalchemy.create_engine(
   sqlalchemy.engine.url.URL(
   drivername=driver_name,
   username=db_user,
   password=db_password,
   database=db_name,
   query=query_string,
   ),
   pool_size=5,
   max_overflow=2,
   pool_timeout=30,
   pool_recycle=1800
   )
   try:
      with db.connect() as conn:
         conn.execute(creator)
         conn.execute(stmt)
         print("Insert successful")
   except Exception as e:
      print ("Some exception occured" + str(e))
      return 'Error: {}'.format(str(e))
   return 'ok'


