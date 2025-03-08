import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final client = MqttServerClient('a2jxh5h70e80uc-ats.iot.us-east-1.amazonaws.com', '');

  String mensagemRecebida = 'Nenhuma mensagem recebida ainda';

  @override
  void initState() {
    super.initState();
    _mqttConnect();
  }

  Future<void> _mqttConnect() async {
    client.port = 1883;
    // client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.logging(on: true);

    // Configuração de callbacks
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .startClean(); // Limpa a sessão anterior

    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      if (kDebugMode) {
        print('Erro de conexão: $e');
      }
      client.disconnect();
    }

    // Inscrição no tópico
    const topico = 'mqtt_teste';
    client.subscribe(topico, MqttQos.atMostOnce);

    // Escuta de mensagens
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      setState(() {
        mensagemRecebida = pt;
      });

      print('Mensagem recebida no tópico ${c[0].topic}: $pt');
    });
  }

  void _publicarMensagem(String mensagem) {
    const topico = 'meu/dispositivo/temperatura';
    final builder = MqttClientPayloadBuilder();
    builder.addString(mensagem);

    client.publishMessage(topico, MqttQos.atMostOnce, builder.payload!);

    print('Mensagem publicada: $mensagem');
  }

  void _onConnected() {
    print('Conectado ao broker MQTT!');
  }

  void _onDisconnected() {
    print('Desconectado do broker MQTT.');
  }

  void _onSubscribed(String topic) {
    print('Inscrito no tópico: $topic');
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController controladorMensagem = TextEditingController();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Exemplo MQTT em Flutter'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Mensagem recebida: $mensagemRecebida',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
              TextField(
                controller: controladorMensagem,
                decoration: InputDecoration(
                  labelText: 'Digite uma mensagem para publicar',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _publicarMensagem(controladorMensagem.text);
                  controladorMensagem.clear();
                },
                child: Text('Publicar Mensagem'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
