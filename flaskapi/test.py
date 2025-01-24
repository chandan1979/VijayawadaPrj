from flask import Flask, jsonify, request
import mysql.connector

app = Flask(__name__)

# Database configuration
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'suriyamysql',
    'database': 'tourism'
}

# API to get all categories
@app.route('/categories', methods=['GET'])
def get_categories():
    try:
        connection = mysql.connector.connect(**db_config)  # Corrected connection statement
        cursor = connection.cursor()
        cursor.execute("SELECT DISTINCT Categories FROM chennaicsv")  # Assuming 'places' table has a 'category' column
        categories = [row[0] for row in cursor.fetchall()]

        cursor.close()
        connection.close()
        return jsonify(categories)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/<Categories>', methods=['GET'])
def get_places(Categories):  # Categories will now be taken from the URL path
    try:
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)
        
        # Query with table name
        query = "SELECT slno as id, places,discription, entryfee,timings, bus_from_koyambedu_bus_stand_direct_connecting_bus,switchingbus, latitude, longitude FROM chennaicsv WHERE Categories = %s"
        cursor.execute(query, (Categories,))
        places = cursor.fetchall()
        
        # Close connection
        cursor.close()
        connection.close()
        
        return jsonify(places)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0", port=5000)

