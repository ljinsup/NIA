package org.vertx.mods.usgs;

import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;

import org.vertx.java.busmods.BusModBase;
import org.vertx.java.core.AsyncResult;
import org.vertx.java.core.Handler;
import org.vertx.java.core.eventbus.Message;
import org.vertx.java.core.json.JsonArray;
import org.vertx.java.core.json.JsonObject;
import org.w3c.dom.Document;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

public class USGS extends BusModBase implements Handler<Message<JsonObject>>{
	protected JsonObject dbConfig;
	private static long id = -1;
	
	@Override
	public void start() {
		super.start();
		
		dbConfig = getOptionalObjectConfig("dbconfig", null);
		
		//dbConfig.removeField("db_name");
		
		//dbConfig.putString("db_name", "usgsdata");
		
		eb.registerHandler("usgsCollect", this);
	}

	@Override
	public void handle(Message<JsonObject> arg0) {
		
		if(id == -1){
			
			//
			try {
				Class.forName("com.mysql.jdbc.Driver");
			} catch (ClassNotFoundException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
			final String url = "jdbc:mysql://localhost:3306/testdb";
			final String username = "root";
			final String password = "zhzha123!@#";
			
			System.out.println("USGS Timer started *******");
			id = vertx.setTimer(1 * 1000 * 60, new Handler<Long>() {
				@Override
				public void handle(Long arg0) {
					System.out.println("USGS Timer - callback *******");
					
					container.deployModule("mongo-persistor", dbConfig, new Handler<AsyncResult<String>>() {
						@Override
						public void handle(AsyncResult<String> info) {
							
							try {
								DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
								DocumentBuilder db = dbf.newDocumentBuilder();
								Document doc = db.parse(new URL("http://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.atom").openStream());
								
								
								
								System.out.println("******************************************************************");
								System.out.println("Updated Time : " + doc.getFirstChild().getChildNodes().item(1).getTextContent());
								
								NodeList nodes = doc.getElementsByTagName("entry");
								
								
								System.out.println("******************************************************************");
								
								String magnitude = " ";
								String time = " ";
								String latitude = " ";
								String longitude = " ";
								String depth = " ";
								
								JsonArray arItems = new JsonArray();
								for(int i = 0; i < nodes.getLength(); i++){
									NodeList childs = nodes.item(i).getChildNodes();
									
									JsonObject objItem = new JsonObject();
									
									for(int j = 0; j < childs.getLength(); j++){
										Node child = childs.item(j);
										switch(child.getNodeName()){
										case "title":
											String[] arTitle = child.getTextContent().substring(2).split(" - ");
											String title = arTitle[1].split(" of ", 2)[1];
											System.out.println(child.getNodeName() + " : " + arTitle[0] + " / " + title);
											
											objItem.putString("title", title);
											objItem.putString("magnitude", arTitle[0]);
											//
											magnitude = arTitle[0];
											break;
										case "updated":
											System.out.println(child.getNodeName() + " : " + child.getTextContent());
											objItem.putString("updated", child.getTextContent());
											
											//
											time = child.getTextContent();
											break;
										case "georss:point":
											System.out.println(child.getNodeName() + " : " + child.getTextContent());
											String[] arGPS = child.getTextContent().split(" ");
											objItem.putString("lat", arGPS[0]);
											objItem.putString("lng", arGPS[1]);
											arItems.addObject(objItem);
											
											//
											latitude = arGPS[0];
											longitude = arGPS[1];
											break;
										//
										case "georss:elev":
											System.out.println(child.getNodeName() + " : " + child.getTextContent());
//											depth = child.getTextContent();
											break;
										}
									}
									
									System.out.println("---------------------------------------------------------------------------------------");
									arItems.add(objItem);
								}
								
								JsonObject sendData = new JsonObject();
								sendData.putString("action", "saveAll");
								sendData.putString("collection", "USGS공공데이터");
								sendData.putArray("document", arItems);
								sendData.putString("db_name", "usgsdata");
								JsonObject data = new JsonObject(sendData.toMap());
								eb.send("mongo-persistor", data);
								
								//
								Connection conn = DriverManager.getConnection(url, username, password);
								Statement stmt = conn.createStatement();
								
								String sql = "INSERT INTO events (EID, Magnitude, Time, Latitude, Longitude, Depth, Idx) VALUE (1 + '" + magnitude +"','" + time +"','" + latitude +"','"+ longitude + "','" + depth + "' + 'asdf')";
								stmt.executeUpdate(sql);
								
								System.out.println("******************************************************************");
								
								
								
								
							} catch (ParserConfigurationException e) {
								// TODO Auto-generated catch block
								e.printStackTrace();
							} catch (MalformedURLException e) {
								// TODO Auto-generated catch block
								e.printStackTrace();
							} catch (SAXException e) {
								// TODO Auto-generated catch block
								e.printStackTrace();
							} catch (IOException e) {
								// TODO Auto-generated catch block
								e.printStackTrace();
							} catch (SQLException e) {
								// TODO Auto-generated catch block
								e.printStackTrace();
							}
							
							
						}
					});
					
				}
			});
		} else {
			System.out.println("Timer is already running");
		}
		
	}

}
