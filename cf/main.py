import sqlalchemy
from google.cloud import storage
import datetime


connection_name = "testsabregcp:us-central1:chadam-db-sql-mysql"

#database name
db_name = "sabre"
db_user = "root"
db_password = "password"
driver_name = 'mysql+pymysql'
query_string = dict({"unix_socket": "/cloudsql/{}".format(connection_name)})

creator = sqlalchemy.text("CREATE TABLE IF NOT EXISTS info (id INT NOT NULL AUTO_INCREMENT, date DATE, hours INT, PRIMARY KEY (id));")

def upload_blob(bucket_name, blob_text, destination_blob_name):
    """Uploads a file to the bucket."""
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)
    html = f"<html><h1>Invoice</h1>Service: IT Services </br>Quantity: {int(blob_text)} hours </br>Rate: 10 PLN / hour </br>Total: {int(blob_text) * 10} PLN</br></html>"
    blob.upload_from_string(html, content_type="text/html")



def writeToSql(request):
   request_json = request.get_json(silent=True)
   action = request_json["action"]

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
         if action == "save":
             date = request_json["date"]
             hours = request_json["hours"]
             stmt = sqlalchemy.text(f"INSERT INTO info ( date, hours ) values ('{date}', {hours})")
             conn.execute(stmt)
             print("Insert successful")
         elif action == "invoice":
             month = request_json["month"]
             stmt = sqlalchemy.text(f"SELECT SUM(hours) FROM info WHERE MONTH(date) = {month}")
             data = str(conn.execute(stmt).fetchall()[0][0])
             upload_blob("chadam-sabre-gcp-bucket", data, f"invoice-{month}.html")
             return f"https://storage.googleapis.com/chadam-sabre-gcp-bucket/invoice-{month}.html"
   except Exception as e:
      print ("Some exception occured" + str(e))
      return 'Error: {}'.format(str(e))
   return 'ok'




