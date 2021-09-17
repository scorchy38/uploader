import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission/permission.dart';
import 'package:folder_picker/folder_picker.dart';
import 'dart:io' as io;
import 'package:flutter/material.dart';

class _FolderPickerDemoState extends State<FolderPickerDemo> {
  Directory externalDirectory;
  Directory pickedDirectory;

  Future<void> getPermissions() async {
    final permissions =
        await Permission.getPermissionsStatus([PermissionName.Storage]);
    var request = true;
    switch (permissions[0].permissionStatus) {
      case PermissionStatus.allow:
        request = false;
        break;
      case PermissionStatus.always:
        request = false;
        break;
      default:
    }
    if (request) {
      await Permission.requestPermissions([PermissionName.Storage]);
    }
  }

  Future<void> getStorage() async {
    final directory = await getExternalStorageDirectory();
    setState(() => externalDirectory = directory);
  }

  void _listofFoldersfromFolder(String folderPath) async {
    setState(() {
      folders = io.Directory(folderPath)
          .listSync(); //use your folder name insted of resume.
    });

    print(folders.runtimeType);
  }

  void _listofFilesfromFolder(String folderPath) async {
    setState(() {
      files = io.Directory(folderPath)
          .listSync(); //use your folder name insted of resume.
    });

    print(files.runtimeType);
  }

  double _progress = 0;
  String url;
  void _uploadFile(File file, String filename, String folderPath) async {
    final FirebaseStorage _storage =
        FirebaseStorage(storageBucket: 'gs://ecom-9a689.appspot.com/');

    StorageReference storageReference;
    storageReference = _storage.ref().child("Products/$folderPath/$filename");

    final StorageUploadTask uploadTask = storageReference.putFile(file);

    uploadTask.events.listen((event) {
      setState(() {
        _progress = (event.snapshot.bytesTransferred.toDouble() /
                event.snapshot.totalByteCount.toDouble()) *
            100;
        print('${_progress.toStringAsFixed(2)}%');
      });
    }).onError((error) {
      print(error);
    });

    final StorageTaskSnapshot downloadUrl = (await uploadTask.onComplete);
    url = (await downloadUrl.ref.getDownloadURL());
    if (filename == "0") {
      Firestore.instance
          .collection('products')
          .document(folderPath)
          .updateData({'images': []});
    }
    await Firestore.instance
        .collection('products')
        .document(folderPath)
        .updateData({
      'images': FieldValue.arrayUnion([url])
    });

    print("URL is $url and done for $folderPath/$filename");

    setState(() async {});
  }

  //Declare Globaly
  List files = new List();
  List folders = new List();

  Future<void> init() async {
    await getPermissions();
    await getStorage();
  }

  @override
  void initState() {
    super.initState();

    init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: (externalDirectory != null)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                        RaisedButton(
                          child:
                              const Text("Pick a folder", textScaleFactor: 1.3),
                          onPressed: () => Navigator.of(context)
                              .push<FolderPickerPage>(MaterialPageRoute(
                                  builder: (BuildContext context) {
                            return FolderPickerPage(
                                rootDirectory: externalDirectory,
                                action: (BuildContext context,
                                    Directory folder) async {
                                  print("Picked directory $folder");
                                  setState(() {
                                    pickedDirectory = folder;
                                    _listofFoldersfromFolder(
                                        pickedDirectory.path);
                                    for (int i = 0; i < folders.length; i++) {
                                      _listofFilesfromFolder(folders[i].path);
                                      for (int j = 0; j < files.length; j++) {
                                        _uploadFile(files[j], j.toString(),
                                            basename(folders[i].path));
                                      }
                                    }
                                  });
                                  Navigator.of(context).pop();
                                });
                          })),
                        ),
                        (pickedDirectory != null)
                            ? Padding(
                                padding: const EdgeInsets.only(top: 30.0),
                                child: Text("${pickedDirectory.path}"),
                              )
                            : const Text('')
                      ])
                : const CircularProgressIndicator()));
  }
}

class FolderPickerDemo extends StatefulWidget {
  @override
  _FolderPickerDemoState createState() => _FolderPickerDemoState();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MM Image Uploader',
      home: FolderPickerDemo(),
      theme: ThemeData.dark(),
    );
  }
}

void main() => runApp(MyApp());
