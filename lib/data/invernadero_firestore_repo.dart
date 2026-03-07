import 'package:cloud_firestore/cloud_firestore.dart';

class InvernaderoFirestoreRepo {
  InvernaderoFirestoreRepo({
    FirebaseFirestore? firestore,
    this.envId = 'dev_local',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String envId;

  DocumentReference<Map<String, dynamic>> get _envDoc =>
      _firestore.collection('apps').doc('invernadero_mvp').collection('envs').doc(envId);

  CollectionReference<Map<String, dynamic>> get ventas =>
      _envDoc.collection('ventas');

  CollectionReference<Map<String, dynamic>> get movimientos =>
      _envDoc.collection('movimientos');

  CollectionReference<Map<String, dynamic>> get lotes =>
      _envDoc.collection('lotes');

  CollectionReference<Map<String, dynamic>> get meta =>
      _envDoc.collection('meta');
}
