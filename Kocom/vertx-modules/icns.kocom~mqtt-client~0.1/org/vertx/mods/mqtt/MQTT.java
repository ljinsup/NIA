package org.vertx.mods.mqtt;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.Random;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import org.eclipse.paho.client.mqttv3.*;
import org.vertx.java.busmods.BusModBase;
import org.vertx.java.core.AsyncResult;
import org.vertx.java.core.Handler;
import org.vertx.java.core.eventbus.Message;
import org.vertx.java.core.json.JsonObject;

public class MQTT extends BusModBase implements Handler<Message<JsonObject>>
{
	protected String host; // MQTT Broker Address
    protected int port; // MQTT Port
    protected String clientID; // MQTT Client ID
    private static MqttClient mClient; // MQTT Client Member
    protected String Address; // Vertx Event Bus Address... (set mqttclient)
    protected JsonObject dbConfig; // Mongodb Config(ip,port...)
    //protected String deployID;
    protected String db_name; // Mongodb DBname
    protected String keytopic; // Mqtt Key Topic(ex) keytopic/ACT)
	protected String key; // Encrypt Key
    protected static String IV = "AAAAAAAAAAAAAAAA"; // Packing string
    protected int tseed1, tseed2; // seed of Encrypt Key. (use SHA256 Algorithm)
    protected String checkID; // value of Register TG
    //protected String pTopic; // 
    //protected int pSecureKey;
    
	@Override
    public void start()
    /*
     * 		called at module deployed
     */
    {
        super.start(); // start Module Func
        port = getOptionalIntConfig("port", 1883);
        host = getOptionalStringConfig("host", "localhost");
        clientID = getOptionalStringConfig("clientID", MqttClient.generateClientId());
        dbConfig = getOptionalObjectConfig("dbConfig", null);
        keytopic = getOptionalStringConfig("key", "kocom");
        //read config... if not set the config.. use defalut value
        Address = "mqttclient";
        try
        {
            mClient = new MqttClient((new StringBuilder("tcp://")).append(host).append(":").append(port).toString(), clientID);
            mClient.connect();
            
            if(mClient == null){
            	System.out.println("client is null!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            } else {
            	System.out.println(mClient.getServerURI());
            }
        }
        catch(MqttException e)
        {
            e.printStackTrace();
        }
        eb.registerHandler(Address, this); // register Module Handler Address
    }

    public void handle(Message<JsonObject> message)
    /*
     * 		start at handler called
     */
    {
    	int length = 30;
    	for(int i = 0; i<length ; i++)
    		System.out.print("=");
    	System.out.print("Handler Called");
    	for(int i = 0; i<length ; i++)
    		System.out.print("=");
    	System.out.println("");
    	System.out.println(((JsonObject)message.body()).toString());
    	System.out.println("");
    	String action = ((JsonObject)message.body()).getString("action"); // handler called... check action...
    	if(action == null)
    	{
    		sendError(message, "Error : action must be specified");
    		return;
    	}
    	System.out.println("action : " + action);
    	
    	switch(action)
    	{
    	case "register": // TG Registor
    		try {
				doRegistor(message);
			} catch (Exception e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
    		break;
    	case "publish": // publish message to MQTT
    		doPublish(message);
    		break;
    	case "subscribe": // subscribe message to MQTT
    		try
    		{
    			System.out.println("startDoSubscribe");
    			doSubscribe(message);
    		}
    		catch(MqttException e1)
    		{
    			e1.printStackTrace();
    		}
    		break;
       	default:
        	sendError(message, (new StringBuilder("Invalid action: ")).append(action).toString());
           	break;
    	}
    }

    private void doSubscribe(Message<JsonObject> message)
        throws MqttException
    /*
     * 		void doSubscribe(message)
     * 		parameter message - {"topic":subscribe topic name}
     */
    {
        String topicdata = getMandatoryString("topic", message);
        
        System.out.println("keytopic : " + keytopic);
        System.out.println("topicdata : " + topicdata);
        
        
        String subtopic = keytopic + "/" + topicdata;
        //String subtopic = (new StringBuilder(String	.valueOf(keytopic))).append("/").append(topicdata).toString();
        
        System.out.println("subtopic : " + subtopic);
        
        
        if(mClient != null && mClient.isConnected()){
        	mClient.subscribe(subtopic);
            
            mClient.setCallback(new MqttCallback() {
                public void connectionLost(Throwable throwable)
                {
                	System.out.println("connection lost");
                }

                public void deliveryComplete(IMqttDeliveryToken imqttdeliverytoken)
                {
                }

                public void messageArrived(String arg0, MqttMessage arg1)
                {
                	try {
                		System.out.println("**********  message : " + arg0);
                		
                		JsonObject doc = new JsonObject(arg1.toString());
                		System.out.println("**********  MQTT : " + doc);
                		subscribeFunc(doc, dbConfig, arg0);	
    				} catch (Exception e) {
    					e.printStackTrace();
    				}
                }
            });
        } else {
        	System.out.println("client is null");
        }
        
        
    }
    
    /*
     * 		void doImport(message)
     * 		parameter message - 
     *  {"url" : $scope.publicAddress,
          "apikey" : $scope.APIkey,
          "collection" : $scope.DataName,
          "period" : $scope.period,
          "dbConfig" : {
          	"host" : "localhost",
          	"port" : 30000,
          	"db_name" : "publicdata"
          }
        }
     */
    
	private void subscribeFunc(final JsonObject doc, final JsonObject dbConfig, final String topicName)
    /*
     * 		void subscribeFunc(doc, dbConfig, topicName)
     * 		parameter doc - {"type":messageType(log,tgdata,....),"document":message}
     * 		parameter dbConfig - {"dbname" : dbname}
     * 		parameter topicName - Full Topic (Key/topic)
     * 		if subscribe... save the message to mongo db
     */
    {
    	eb = vertx.eventBus();
    	container.deployModule("mongo-persistor", dbConfig, new Handler<AsyncResult<String>>() {
    		@Override
    		public void handle(AsyncResult<String> info) {
    			String[] divid = topicName.split("\\/"); // divide full topic....
    	    	
    			final String FuncID = divid[1];
    			
    			switch(FuncID)
    			{
    			case "Log": 
    				db_name = "logdata";
    				break;
    			case "TGdata": 
    				db_name = "sensordata";
    				break;
    			case "EPL":
    			case "ACT":
    				return; // if EPL, ACT... do not action
    			case "PDImport": // public data added
    				
    				/*{"url":"openapi.airkorea.or.kr/openapi/services/rest/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty?numOfRows=1&pageNo=1&stationName=%EC%86%A1%ED%8C%8C%EA%B5%AC&dataTerm=DAILY&",
    				 * "apikey":"g2PYYeRkm4XwNs5SkT%2BEm6ZWuLXQCBNLJ4jdEH43rTuU0WjKjo%2B2IBtyAr1EJmS2QqsImnnT3RCr5RNBZ0d25A%3D%3D",
    				 * "collection":"\ub300\uae30\uc815\ubcf4\ub370\uc774\ud130",
    				 * "period":"1"}
    				 * */
    				
    				
//    				JsonObject objPublicData = new JsonObject();
//    				JsonObject objConfig = new JsonObject();
//    				objConfig.putString("host", "localhost");
//    				objConfig.putNumber("port", 30000);
//    				objConfig.putString("db_name", "publicdata");
//    				objPublicData.putObject("dbconfig", objConfig);
//    				objPublicData.putString("url", doc.getString("url"));
//    				objPublicData.putString("apikey", doc.getString("apikey"));
//    				objPublicData.putString("collection", doc.getString("collection"));
//    				objPublicData.putString("period", doc.getString("period"));
//    				
//    				eb.send("pdCollector", objPublicData);
    				
    				System.out.println("Public data worker will be performed...");
    				
    				
    				JsonObject objTGInfo = new JsonObject();
    				objTGInfo.putString("tgID", "TG01");
    				objTGInfo.putString("secureNum", "123456");
    				eb.send("tgRegister", objTGInfo);
    				
    				System.out.println("TG is registered...");
    				
//    				JsonObject objPDInfo = new JsonObject();
//    				
//    				objPDInfo.putString("action", "save");
//    				objPDInfo.putString("collection", "pdList");
//    				objPDInfo.putString("db_name", "scconfig");
//    				objPDInfo.putObject("document", doc);
//    				
//    				eb.send("mongo-persistor", objPDInfo);
//    				
//    				System.out.println("Public data information is stored");
    				
    				return;
    			case "PDRemove":
    				JsonObject objPDInfo = new JsonObject();
    				objPDInfo.putString("worker", doc.getString("worker"));
    				eb.send("pdRemover", objPDInfo);
    				return;
    			case "usgsCollect" :
    				JsonObject objUSGSInfo = new JsonObject();
    				JsonObject objDBConfig = new JsonObject();
    				objDBConfig.putString("host", "localhost");
    				objDBConfig.putNumber("port", 30000);
    				objDBConfig.putString("db_name", "publicdata");
    				objUSGSInfo.putObject("dbconfig", objDBConfig);
    				eb.send("usgsCollector", objUSGSInfo);
    				return;
    			case "registerTG" :
//    				JsonObject objTGInfo = new JsonObject();
//    				objTGInfo.putString("tgID", "TG01");
//    				objTGInfo.putString("secureNum", "123456");
//    				eb.send("tgRegister", objTGInfo);
    				return;
    			default:
    				System.out.println((new StringBuilder("Unknown Message: ")).append(doc.getString("Type")).toString());
    				return;
    			}
    			
    			final String TGID = divid[2];
    			
    			doc.removeField("type");
    			if(dbConfig.containsField("db_name"))
    				dbConfig.removeField("db_name");
    			dbConfig.putString("db_name", db_name);
    			SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.KOREA);
    			Date currentTime = new Date();
    			String dTime = formatter.format(currentTime); // add to time at message
    			doc.putString("time", dTime);
    			JsonObject sendData = new JsonObject();
    			sendData.putString("collection",TGID);
    			doc.removeField("TG_ID");
    			
    			sendData.putString("action", "save");
    			sendData.putObject("document", doc);
    			String dbname = dbConfig.getString("db_name");
    			sendData.putString("db_name", dbname);
    			System.out.println("store received Message in DB");	
    			System.out.println(sendData.toString());
    			eb.send("mongo-persistor", sendData);
    		}
    		
    	});
    }

    private void doPublish(Message<JsonObject> message)
    /*
     * 		void doPublish(message)
     * 		parameter message - {"topic":topic name, "document":message"}
     * 		publish message to topic
     */
    {
        String topic = getMandatoryString("topic", message);
        if(topic == null)
            return;
        JsonObject doc = getMandatoryObject("document", message);
        if(doc == null)
            return;
        MqttMessage mMessage = new MqttMessage(doc.toString().getBytes());
        try
        {
        	MqttTopic topictest = mClient.getTopic((new StringBuilder(String.valueOf(keytopic))).append("/").append(topic).toString());
            MqttDeliveryToken token = topictest.publish(mMessage);
            token.waitForCompletion(1000);
        }
        catch(MqttPersistenceException e)
        {
            e.printStackTrace();
        }
        catch(MqttException e)
        {
            e.printStackTrace();
        }
    }

    private void doRegistor(Message<JsonObject> message) throws Exception
    /*
     * 		void doRegistor(message)
     * 		parameter message - {"tgID":thin-gateway id, "secureNum":secure number for registor}
     * 		register Thin-gateway... use AES Algorithm
     * 		Encrypted key : using SHA256... -> use 16 char 
     */
    {
    	checkID = getMandatoryString("tgID", message);
    	if(checkID == null)
    		return;
    	int secureNum = (Integer) message.body().getNumber("secureNum");
    	int seed1, seed2; // secureNumber divide to 2 number(000/000)
    	seed1 = secureNum/1000;
    	seed2 = secureNum%1000;
    	key = SHA256(seed1, seed2); // make key
    	System.out.println("SHA Key : " + key);
    	System.out.println("topic : " + keytopic);
    	System.out.println("");
    	Random random = new Random();
    	
    	tseed1 = random.nextInt(999)+1;
    	tseed2 = random.nextInt(999)+1;
    	// make two of random number..(for session key)
    	
    	JsonObject Message,regiMessage;
    	Message = new JsonObject();
    	regiMessage = new JsonObject();
    	System.out.println("seed Number : " + tseed1 + " " + tseed2);
    	    	
    	Message.putValue("num1", tseed1);
    	Message.putValue("num2", tseed2);
    	// packaged session key 
    	
    	byte[] encryptMessage;
    	
    	encryptMessage = encrypt(Message.toString(),key); // encrypt message.
    	regiMessage.putString("type", "00"); // type 00 : register step of 1
        regiMessage.putBinary("data", encryptMessage);
        
        System.out.println("Encrypt : " + Message.toString() + " -> ");
        for (int i=0; i<encryptMessage.length; i++)
	    	System.out.print(new Integer(encryptMessage[i])+" ")	;
	    System.out.println("");
    	System.out.println("");
        
    	MqttMessage mMessage = new MqttMessage(regiMessage.toString().getBytes());
    	// transfer message to Byte Code
    	try
    	{
    		mClient.publish(checkID, mMessage);
    		// publish Message
    	}
    	catch(MqttPersistenceException e)
    	{
    		e.printStackTrace();
    	}
    	catch(MqttException e)
    	{
    		e.printStackTrace();
    	}
    	
    	key = SHA256(tseed1, tseed2); // save the session key
    	    	
    	try {
			mClient.subscribe(checkID); // wait the return to message
		} catch (MqttException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
    	mClient.setCallback(new MqttCallback() {
    		public void connectionLost(Throwable throwable)
    		{
    		}
    		
    		public void deliveryComplete(IMqttDeliveryToken imqttdeliverytoken)
    		{
    		}
    		
    		public void messageArrived(String arg0, MqttMessage arg1)
    				throws Exception
    		{	
    			System.out.println(arg1.toString());
    			JsonObject doc = new JsonObject(arg1.toString());
    			registerSubFunc(doc); // if return the message... call the function
    		}	
    	});
    }
    
    private void registerSubFunc(final JsonObject doc) throws Exception
    /*
     * 		void registerSubFunc(doc)
     * 		parameter doc - {"data":encrypted message(E(tgid))}
     * 		check session key... and send keytopic
     */
    {
    	if(doc.getNumber("Number")!=null) // if Number value is not null... exit the func
    	{
    		return;
    	}
    	Boolean unsub = false;
		JsonObject Message,sendMessage;
    	Message = new JsonObject();
    	byte[] encryptMessage = null;
    	sendMessage = new JsonObject();
    	byte[] encryptData = doc.getBinary("data");
        
    	String Data = decrypt(encryptData,key); // decrypt Message....
    		System.out.print("decrypt : ");
	    for (int i=0; i<encryptData.length; i++)
	    	System.out.print(new Integer(encryptData[i])+" ");
	    System.out.println(" -> " + Data);
    	System.out.println("");
    	String[] Datas = Data.split(" ");
    	Thread.sleep(2000); // wait sync
    	if(checkID.equalsIgnoreCase(Datas[0])) // decrypted message == tgid...
    	{
    		System.out.println("client's Key is correct.");
        	key = SHA256(tseed1, tseed2); // encrypted key
    		Message.putString("topic", keytopic);
    		
    		encryptMessage = encrypt(Message.toString(), key); // encrypt keytopic
    		unsub = true; // unsubscribe check
    		
    		System.out.println("Encrypt : " + Message.toString() + " -> " );
    	    for (int i=0; i<encryptMessage.length; i++)
    	    	System.out.print(new Integer(encryptMessage[i])+" ")	;
    	    System.out.println("");
    		sendMessage.putString("type","01"); // type 01 : register step 3
    	}
    	else // session key is incorrect...
    	{
    		String checkString = doc.getString("notice");
        	if(checkString == null)
        	{
        		System.out.println("client's Key is incorrect... resend seed number");
            	System.out.println("");
        		Message.putValue("num1", tseed1);
        		Message.putValue("num2", tseed2);
        	        	
        		encryptMessage = encrypt(Message.toString(),key);
        		sendMessage.putString("type","00");
        		//resend data
        	}
    	}
    	
    	if(encryptMessage != null)
    	{
    		sendMessage.putBinary("data", encryptMessage);
    		
    		MqttMessage mMessage = new MqttMessage(sendMessage.toString().getBytes());
        	MqttTopic topictest = mClient.getTopic(checkID);
            MqttDeliveryToken token = topictest.publish(mMessage);
            // publish encrypted keytopic
            token.waitForCompletion(1000);
            // wait sync
    		
    		if(unsub == true)
    		{
    			System.out.println("End of Register");
    			mClient.unsubscribe(checkID);
    			// unsubscribe register channel
    		}
    	}
    }
    
    public byte[] encrypt(String plainText, String encryptionKey) throws Exception {
    	/*
    	 * 		byte[] encrypt(plainText, encryptionKey)
    	 * 		return type byte[] - encrypted Message
    	 * 		parameter plainText - plainText
    	 * 		parameter encryptionKey - Key for encrypt
    	 * 		Encrypt Data using AES Algorithm, return to byte code
    	 */
    	plainText = MakeMultipleHexD(plainText);
    	Cipher cipher = Cipher.getInstance("AES/CBC/NoPadding", "SunJCE");
    	SecretKeySpec key = new SecretKeySpec(encryptionKey.getBytes("UTF-8"), "AES");
    	cipher.init(Cipher.ENCRYPT_MODE, key,new IvParameterSpec(IV.getBytes("UTF-8")));
    	return cipher.doFinal(plainText.getBytes("UTF-8"));
    }
    
    public String decrypt(byte[] cipherText, String encryptionKey) throws Exception{
    	/*
    	 * 		String decrypt(cipherText, encryptionKey)
    	 * 		return type String - plainText
    	 * 		parameter cipherText - Encrypted Message
    	 * 		parameter encryptionKey - Key for decrypt
    	 * 		Decrypt Data using AES Algorithm, return to String
    	 */	
    	Cipher cipher = Cipher.getInstance("AES/CBC/NoPadding", "SunJCE");
    	SecretKeySpec key = new SecretKeySpec(encryptionKey.getBytes("UTF-8"), "AES");
    	cipher.init(Cipher.DECRYPT_MODE, key,new IvParameterSpec(IV.getBytes("UTF-8")));
    	return new String(cipher.doFinal(cipherText),"UTF-8");
    }
    
    public String SHA256(int num1, int num2){
    	/*
    	 * 		String SHA256(num1,num2)
    	 * 		return type String - KEY
    	 * 		parameter num1 - seed number 1 for session key
    	 * 		parameter num2 - seed number 2 for session key
    	 * 		make key for encrypt.... SHA256 -> make 64 string.....
    	 * 		substring 16 string(0 to 15)
    	 */
    	String SHA = "12345612431512315123154123"; // padding data
    	try{
    		MessageDigest sh = MessageDigest.getInstance("SHA-256"); 
    		String str = String.valueOf((num1+1)*(num1-1)*(num2+1)*(num2-1));
    		sh.update(str.getBytes()); 
    		byte byteData[] = sh.digest();
    		StringBuffer sb = new StringBuffer(); 
    		for(int i = 0 ; i < byteData.length ; i++){
    			sb.append(Integer.toString((byteData[i]&0xff) + 0x100, 16).substring(1));
    		}
    		SHA = sb.toString();
    		
    	}catch(NoSuchAlgorithmException e){
    		e.printStackTrace(); 
    		SHA = null; 
    	}
    	SHA = SHA.substring(0,16);
    	// substring SHA256 data... -> key 
    	return SHA;
    }
    
    public static byte[] stringToByte(String str)
    /*
     * 		byte[] stringToByte(str)
     * 		return type byte[] - byte code
     * 		parameter str - String data
     * 		transfer string to byte code
     */
    { 
    	int strLen = str.length();
    	byte[] cVal = new byte[strLen];
    	cVal = str.getBytes();
    	
    	return cVal;
    }
        
    public String MakeMultipleHexD(String input)
    /*
     * 		String MakeMultipleHexD(input)
     * 		return type String - padded String
     * 		input - Original String
     * 		padding the String
     */
    {
    	int size = input.length();
    	size = size%16;
    	if(size != 0)
    		size = 16-size;
    	// check the message of size
    	StringBuilder strBuf = new StringBuilder(input);
    	for(int i = 0; i<size; i++)
    	{
    		 strBuf.append(" ");
    	}
    	// added blank data to make multiple of 16
    	input = strBuf.toString();
		return input;
    }
}