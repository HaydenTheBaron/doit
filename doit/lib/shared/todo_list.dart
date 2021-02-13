import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

class TaskList extends StatelessWidget {
  const TaskList({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamProvider<QuerySnapshot>(
        create: (context) =>
            FirebaseFirestore.instance.collection("tasks").snapshots(),
        child: TaskListBuilder(),
      ),
    );
  }
}

class TaskListBuilder extends StatelessWidget {
  const TaskListBuilder({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ListView.builder(
        itemCount: Provider.of<QuerySnapshot>(context)
            .docs
            .length, // FIXME: this is breifly null and causes an error screen briefly (I think)
        itemBuilder: (context, idx) {
          var tasksDoc = Provider.of<QuerySnapshot>(context).docs[
              idx]; // FIXME: this is breifly null and causes an error screen briefly (I think)
          return Provider<int>(
            create: (context) => idx,
            child: TaskTile(
              description: tasksDoc['description'],
              isChecked: tasksDoc['isChecked'],
            ),
          );
        },
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  const TaskTile({Key key, this.description, this.isChecked}) : super(key: key);

  final String description;
  final bool isChecked;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      // Can swipe right to dismiss TaskTile
      key: Key(Provider.of<QuerySnapshot>(context)
          .docs[Provider.of<int>(context)] // .docs[idx]
          .reference
          .hashCode
          .toString()),
      child: ListTile(title: Text(this.description), leading: Checkbox()),
      onDismissed: (DismissDirection direction) =>
          onTaskTileDismissed(context, direction),
      background: Container(
        padding: const EdgeInsets.fromLTRB(0, 0, 24, 0),
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.delete,
          color: Colors.white,
        ),
        color: Colors.red,
      ),
    );
  }
}

// TODO: factor out into another file
void onTaskTileDismissed(
    BuildContext context, DismissDirection direction) async {
  await FirebaseFirestore.instance.runTransaction((transaction) async {
    await transaction.delete(Provider.of<QuerySnapshot>(context, listen: false)
        .docs[Provider.of<int>(context, listen: false)]
        .reference);
  });

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text("Task deleted"),
    duration: Duration(milliseconds: 300),
  ));
}

class Checkbox extends StatelessWidget {
  const Checkbox({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var gestureDetector = GestureDetector(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Icon(
          Provider.of<QuerySnapshot>(context)
                      .docs[Provider.of<int>(context, listen: false)]
                  ['isChecked'] // Get currentdocument.isChecked
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          size: 26,
        ),
      ),
      onTap: () => onTapCheckbox(context),
    );
    return Container(
      child: gestureDetector,
    );
  }
}

// TODO: factor this out into a separate file
void onTapCheckbox(BuildContext context) {
  // https://www.youtube.com/watch?v=DqJ_KjFzL9I
  FirebaseFirestore.instance.runTransaction((transaction) async {
    DocumentSnapshot freshSnap = await transaction.get(
        Provider.of<QuerySnapshot>(context, listen: false)
            .docs[Provider.of<int>(context, listen: false)]
            .reference);
    await transaction.update(freshSnap.reference, {
      'isChecked': !freshSnap['isChecked'],
    });
  });
}

// TODO: BKMRK: Implement ability to add new by pressing the FAB. Do this in tasks_screen.dart, using provider

// Old code below //////////////////////////////////////////////////////

class TodoList extends StatefulWidget {
  TodoList({Key key}) : super(key: key);

  @override
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final _formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
          stream: FirebaseFirestore.instance.collection("tasks").snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text('TodoList Loading...');
            return ListView.builder(
              itemCount: snapshot.data.docs.length,
              itemBuilder: (BuildContext context, int idx) {
                var document = snapshot.data.docs[idx];
                return Dismissible(
                  background: Container(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 24, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      color: Colors.red),
                  key: Key(
                      snapshot.data.docs[idx].reference.hashCode.toString()),
                  onDismissed: (direction) async {
                    await FirebaseFirestore.instance
                        .runTransaction((transaction) async {
                      await transaction
                          .delete(snapshot.data.docs[idx].reference);
                    });

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Task deleted"),
                      duration: Duration(milliseconds: 300),
                    ));
                  },
                  child: ListTile(
                      leading: GestureDetector(
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Icon(
                            document['isChecked']
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 26,
                          ),
                        ),
                        onTap: () {
                          // https://www.youtube.com/watch?v=DqJ_KjFzL9I
                          FirebaseFirestore.instance
                              .runTransaction((transaction) async {
                            DocumentSnapshot freshSnap =
                                await transaction.get(document.reference);
                            await transaction.update(freshSnap.reference, {
                              'isChecked': !freshSnap['isChecked'],
                            });
                          });
                        },
                      ),
                      title: Text(document['description']),
                      tileColor: Theme.of(context).accentColor),
                );
              },
            );
          }),
      floatingActionButton: FloatingActionButton(
        // TODO: refactor so that the FAB is part of the screen and not the todolist
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(
          Icons.add,
          color: Theme.of(context).accentColor,
        ),
        onPressed: () {
          // Input task
          showModalBottomSheet<void>(
            context: context,
            builder: (BuildContext context) {
              return Container(
                height: 1000,
                color: Theme.of(context).accentColor,
                child: Center(
                  // CREATE TASK FORM // ---------------------------------------
                  child: Scaffold(
                    body: Form(
                      key: _formKey,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                              child: TextFormField(
                                controller: descriptionController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: "Task Description",
                                ),
                                validator: (value) {
                                  if (value.isEmpty) {
                                    return "Please enter some text";
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),

                          // Finish creating task button
                          StreamBuilder(
                              stream: FirebaseFirestore.instance
                                  .collection("tasks")
                                  .snapshots(),
                              builder: (context, snapshot) {
                                return FlatButton(
                                  //color: Theme.of(context).accentColor,
                                  minWidth: 30,
                                  onPressed: () async {
                                    // Then, later in a transaction:

                                    // Validate will return true if the form is valid, or false if
                                    // the form is invalid.
                                    if (_formKey.currentState.validate()) {
                                      await FirebaseFirestore.instance
                                          .runTransaction((transaction) async {
                                        // Create a reference to a document that doesn't exist yet, it has a random id
                                        final newDocRef =
                                            await FirebaseFirestore.instance
                                                .collection('tasks')
                                                .doc();
                                        // Then, later in a transaction:
                                        transaction.set(newDocRef, {
                                          'description':
                                              descriptionController.text,
                                          'isChecked': false
                                        });
                                      });

                                      descriptionController.text = "";
                                      await Navigator.pop(context);
                                    }
                                  },
                                  child: Icon(
                                    Icons.arrow_right_alt,
                                    size: 35,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                );
                              }),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
