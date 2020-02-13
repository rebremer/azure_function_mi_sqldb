import logging
import requests
import pyodbc
import struct
import os
import azure.functions as func

# Make sure the following user is added 
# 
# CREATE USER [<<Azure Function Identity Name>>] FROM EXTERNAL PROVIDER;
# EXEC sp_addrolemember [db_datareader], [<<Azure Function Identity Name>>]
# 

msi_endpoint = os.environ["MSI_ENDPOINT"]
msi_secret = os.environ["MSI_SECRET"]

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')


    token_auth_uri = f"{msi_endpoint}?resource=https%3A%2F%2Fdatabase.windows.net%2F&api-version=2017-09-01"
    head_msi = {'Secret':msi_secret}
    resp = requests.get(token_auth_uri, headers=head_msi)
    access_token = resp.json()['access_token']

    accessToken = bytes(access_token, 'utf-8')
    exptoken = b""
    for i in accessToken:
        exptoken += bytes({i})
        exptoken += bytes(1)
    tokenstruct = struct.pack("=i", len(exptoken)) + exptoken

    server  = 'test-edlprod1-dbs.database.windows.net'
    database = 'blog-adfv2sec-sqldb'
    connstr = 'DRIVER={ODBC Driver 17 for SQL Server};SERVER='+server+';DATABASE='+database
    #tokenstruct = struct.pack("=i", len(exptoken)) + exptoken
    conn = pyodbc.connect(connstr, attrs_before = { 1256:tokenstruct })
    
    cursor = conn.cursor()
    cursor.execute("select @@version")
    row = cursor.fetchall()
    return func.HttpResponse(str(row))