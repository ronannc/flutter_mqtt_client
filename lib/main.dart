import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Flutter App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ValueNotifier<String?> _valueListenableBuilder = ValueNotifier(null);
  late final MqttServerClient? _client;
  late final String? clientId;
  final String host = 'http://localhost:8000';

  /// Registra o cliente no AWS Iot Core, criando certificado, policy, think e
  /// associando tudo.
  Future<void> _registerClient() async {
    clientId = _clientIdController.text;
    final response = await http.post(
      Uri.parse('$host/api/register-client'),
      body: {'client_id': clientId},
    );
    if (response.statusCode == 200) {
      await connectClient(jsonDecode(response.body));
    } else {
      throw Exception('Erro ao configurar Iot para o cliente');
    }
  }

  Future<void> connectClient(Map<String, dynamic> clientData) async {
    _client = MqttServerClient(clientData['endpoint'], clientId!);

    // Porta para ssl/tls
    _client!.port = 8883;
    _client.secure = true;
    _client.securityContext = SecurityContext.defaultContext;
    _client.securityContext.useCertificateChainBytes(
      utf8.encode(clientData['certificatePem']),
    );
    _client.securityContext.usePrivateKeyBytes(
      utf8.encode(clientData['privateKey']),
    );
    // _client.keepAlivePeriod = 120;

    // Callbacks
    _client.onDisconnected = onDisconnected;
    _client.onConnected = onConnected;
    _client.onSubscribed = onSubscribed;

    _client.logging(on: true); // Habilita logs para debug

    try {
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId!)
          .startClean() // Inicia uma nova sessão limpa
          .withWillQos(MqttQos.atMostOnce);
      _client.connectionMessage = connMessage;
      await _client.connect();

      // Depois de conectar, se inscreve num topico
      _client.subscribe('client/$clientId', MqttQos.atMostOnce);

      _clientsUpdates();
      _clientPublish();
    } on NoConnectionException catch (e) {
      print('NoConnectionException - $e');
      _client.disconnect();
    } on SocketException catch (e) {
      print('SocketException - $e');
      _client.disconnect();
    }
  }

  void _clientPublish() {
    _client!.published!.listen((MqttPublishMessage message) {
      print(
        'Menssagem publicada no topico: ${message.variableHeader!.topicName}',
      );
    });
  }

  void _clientsUpdates() {
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      print("Topico: ${c[0].topic}: $pt");
      _valueListenableBuilder.value = "Topico: ${c[0].topic}: $pt";
    });
  }

  void onSubscribed(String topic) {
    print('Subscrição confirmada para o topico: $topic');
  }

  void onDisconnected() {
    print('OnDisconnected cliente callback');
    if (_client!.connectionStatus!.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      print('OnDisconnected callback foi solicitado, tudo certo!');
    } else {
      print('OnDisconnected callback nao solicitado, algo errado!');
    }
  }

  void onConnected() {
    print('Cliente conectado com sucesso!');
  }

  void publishMessage(String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client!.publishMessage(
      "client/$clientId",
      MqttQos.atMostOnce,
      builder.payload!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('IoT Flutter App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _clientIdController,
              decoration: InputDecoration(labelText: 'Cliente ID'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _registerClient();
              },
              child: Text('Registrar e conectar'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(labelText: 'Menssagem'),
            ),
            ElevatedButton(
              onPressed: () {
                publishMessage(_messageController.text);
              },
              child: Text('Publicar menssagem'),
            ),
            ValueListenableBuilder(
              valueListenable: _valueListenableBuilder,
              builder: (context, value, child) {
                return Text(value ?? 'Nada publicado ainda!');
              },
            ),
          ],
        ),
      ),
    );
  }
}
