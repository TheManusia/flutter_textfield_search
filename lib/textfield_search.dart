import 'dart:async';

import 'package:flutter/material.dart';

typedef ItemBuilder<T> = Widget Function(T item);

typedef ItemLabel<T> = String Function(T item);

typedef LoadingBuilder = Widget Function();

typedef FutureData<T> = Future<List<T>> Function(String);

class TextFieldSearch<T> extends StatefulWidget {
  /// A default list of values that can be used for an initial list of elements to select from
  final List<T>? initialList;

  /// Deprecated use [decoration.hintText] instead
  @Deprecated('Use [decoration.hintText] instead')
  final String? label;

  /// A controller for an editable text field
  final TextEditingController controller;

  /// An optional future or async function that should return a list of selectable elements
  final FutureData<T>? future;

  /// The value selected on tap of an element within the list
  final Function? getSelectedValue;

  /// Used for customizing the display of the TextField
  final InputDecoration? decoration;

  /// Used for customizing the style of the text within the TextField
  final TextStyle? textStyle;

  /// The minimum length of characters to be entered into the TextField before executing a search
  final int minStringLength;

  /// Return the value of TextField
  final Function? onChanged;

  /// Used for customizing the display of each list item with default item
  final ItemLabel<T> itemLabel;

  /// Used for customizing the display of each list item with custom item
  final ItemBuilder<T>? itemBuilder;

  /// Used for customizing the display of the loading indicator
  final LoadingBuilder? loadingBuilder;

  /// Creates a TextFieldSearch for displaying selected elements and retrieving a selected element
  const TextFieldSearch({
    Key? key,
    this.initialList,
    @Deprecated('Use [decoration.hintText] instead') this.label,
    required this.controller,
    this.textStyle,
    this.future,
    this.getSelectedValue,
    this.decoration,
    this.minStringLength = 2,
    this.onChanged,
    required this.itemLabel,
    this.itemBuilder,
    this.loadingBuilder,
  })  : assert(initialList != null || future != null),
        super(key: key);

  @override
  _TextFieldSearchState createState() => _TextFieldSearchState<T>();
}

class _TextFieldSearchState<T> extends State<TextFieldSearch<T>> {
  final FocusNode _focusNode = FocusNode();
  late OverlayEntry _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  List<T>? filteredList = <T>[];
  bool hasFuture = false;
  bool loading = false;
  final _debouncer = Debouncer(milliseconds: 1000);
  bool? itemsFound;

  void resetList() {
    List<T> tempList = <T>[];
    setState(() {
      // after loop is done, set the filteredList state from the tempList
      this.filteredList = tempList;
      this.loading = false;
    });
    // mark that the overlay widget needs to be rebuilt
    this._overlayEntry.markNeedsBuild();
  }

  void setLoading() {
    if (!this.loading) {
      setState(() {
        this.loading = true;
      });
    }
  }

  void resetState(List<T> tempList) {
    setState(() {
      // after loop is done, set the filteredList state from the tempList
      this.filteredList = tempList;
      this.loading = false;
      // if no items are found, add message none found
      itemsFound = tempList.length == 0 && widget.controller.text.isNotEmpty ? false : true;
    });
    // mark that the overlay widget needs to be rebuilt so results can show
    this._overlayEntry.markNeedsBuild();
  }

  void updateList() {
    this.setLoading();
    // set the filtered list using the initial list
    this.filteredList = widget.initialList;
    // create an empty temp list
    List<T> tempList = <T>[];
    // loop through each item in filtered items
    for (int i = 0; i < filteredList!.length; i++) {
      // lowercase the item and see if the item contains the string of text from the lowercase search
      if (this.widget.itemLabel(filteredList![i]).toLowerCase().contains(widget.controller.text.toLowerCase())) {
        // if there is a match, add to the temp list
        tempList.add(this.filteredList![i]);
      }
    }
    // helper function to set tempList and other state props
    this.resetState(tempList);
  }

  void initState() {
    super.initState();

    if (widget.future != null) {
      setState(() {
        hasFuture = true;
      });
    }

    // add event listener to the focus node and only give an overlay if an entry
    // has focus and insert the overlay into Overlay context otherwise remove it
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        this._overlayEntry = this._createOverlayEntry();
        Overlay.of(context)!.insert(this._overlayEntry);
      } else {
        this._overlayEntry.remove();
        // check to see if itemsFound is false, if it is clear the input
        // check to see if we are currently loading items when keyboard exists, and clear the input
        if (itemsFound == false || loading == true) {
          // reset the list so it's empty and not visible
          resetList();
          widget.controller.clear();
        }
        // if we have a list of items, make sure the text input matches one of them
        // if not, clear the input
        if (filteredList!.length > 0) {
          bool textMatchesItem = false;
          if (widget.getSelectedValue != null) {
            // try to match the label against what is set on controller
            textMatchesItem = filteredList!.any((item) => item == widget.controller.text);
          } else {
            textMatchesItem = filteredList!.contains(widget.controller.text);
          }
          if (textMatchesItem == false) widget.controller.clear();
          resetList();
        }
      }
    });
  }

  ListView _listViewBuilder(context) {
    if (itemsFound == false) {
      return ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              // clear the text field controller to reset it
              widget.controller.clear();
              setState(() {
                itemsFound = false;
              });
              // reset the list so it's empty and not visible
              resetList();
              // remove the focus node so we aren't editing the text
              FocusScope.of(context).unfocus();
            },
            child: ListTile(
              title: Text('No matching items.'),
              trailing: Icon(Icons.cancel),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      itemCount: filteredList!.length,
      itemBuilder: (context, i) {
        return StatefulBuilder(builder: (context, updateState) {
          return InkWell(
            onTap: () {
              // set the controller value to what was selected
              setState(() {
                // if we have a label property, and getSelectedValue function
                // send getSelectedValue to parent widget using the label property
                if (widget.getSelectedValue != null) {
                  widget.controller.text = widget.itemLabel(filteredList![i]);
                  widget.getSelectedValue!(filteredList![i]);
                } else {
                  widget.controller.text = widget.itemLabel(filteredList![i]);
                }
              });
              // reset the list so it's empty and not visible
              resetList();
              // remove the focus node so we aren't editing the text
              FocusScope.of(context).unfocus();
            },
            child: widget.itemBuilder != null
                ? (widget.itemBuilder!(filteredList![i]))
                : ListTile(
                    title: Text(
                      widget.itemLabel(filteredList![i]),
                    ),
                  ),
          );
        });
      },
      padding: EdgeInsets.zero,
      shrinkWrap: true,
    );
  }

  /// A default loading indicator to display when executing a Future
  Widget _loadingIndicator() {
    if (widget.loadingBuilder != null)
      return widget.loadingBuilder!();
    return Container(
      width: 50,
      height: 50,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
        ),
      ),
    );
  }

  Widget? _listViewContainer(context) {
    if (itemsFound == true && filteredList!.length > 0 || itemsFound == false && widget.controller.text.length > 0) {
      double _height = itemsFound == true && filteredList!.length > 1
          ? (filteredList!.length > 4 ? 55 * 4 : filteredList!.length * 55)
          : 55;
      return Container(
        height: _height,
        child: _listViewBuilder(context),
      );
    }
    return null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Size overlaySize = renderBox.size;
    Size screenSize = MediaQuery.of(context).size;
    double screenWidth = screenSize.width;
    return OverlayEntry(
      builder: (context) => Positioned(
        width: overlaySize.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, overlaySize.height + 5.0),
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: screenWidth,
                  maxWidth: screenWidth,
                  minHeight: 0,
                  // max height set to 150
                  maxHeight: itemsFound == true && filteredList!.length > 1
                      ? (filteredList!.length > 4 ? 55 * 4 : filteredList!.length * 55)
                      : 55,
                ),
                child: loading ? _loadingIndicator() : _listViewContainer(context)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: this._layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: this._focusNode,
        decoration: widget.decoration,
        style: widget.textStyle,
        onChanged: (String value) {
          if (widget.onChanged != null) widget.onChanged!(value);
          // every time we make a change to the input, update the list
          _debouncer.run(() {
            setState(() {
              if (hasFuture) {
                updateGetItems();
              } else {
                updateList();
              }
            });
          });
        },
      ),
    );
  }

  void updateGetItems() {
    // mark that the overlay widget needs to be rebuilt
    // so loader can show
    this._overlayEntry.markNeedsBuild();
    if (widget.controller.text.length > widget.minStringLength) {
      this.setLoading();
      widget.future!(widget.controller.text).then((value) {
        // helper function to set tempList and other state props
        this.resetState(value);
      });
    } else {
      // reset the list if we ever have less than 2 characters
      resetList();
    }
  }
}

class Debouncer {
  /// A length of time in milliseconds used to delay a function call
  final int? milliseconds;

  /// A callback function to execute
  VoidCallback? action;

  /// A count-down timer that can be configured to fire once or repeatedly.
  Timer? _timer;

  /// Creates a Debouncer that executes a function after a certain length of time in milliseconds
  Debouncer({this.milliseconds});

  run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds!), action);
  }
}
