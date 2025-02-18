import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:org_flutter/src/entity.dart';
import 'package:org_flutter/src/util/util.dart';
import 'package:org_parser/org_parser.dart';

const _kDefaultSearchQuery = '';
const _kDefaultHideMarkup = false;
const _kDefaultVisibilityState = OrgVisibilityState.folded;

const _kTransientStateNodeMapKey = 'node_map';

enum OrgVisibilityState {
  /// Just the root headline; equivalent to global "overview" state
  folded,

  /// All headlines of all levels
  contents,

  /// All immediate children (subtrees folded)
  children,

  /// Everything
  subtree,
}

String? _orgVisibilityStateToJson(OrgVisibilityState? value) =>
    value?.toString();

OrgVisibilityState? _orgVisibilityStateFromJson(String? json) => json == null
    ? null
    : OrgVisibilityState.values.singleWhere(
        (value) => value.toString() == json,
      );

/// A collection of temporary data about an Org Mode document used for display
/// purposes.
class OrgDataNodeMap {
  factory OrgDataNodeMap.build({
    required OrgTree root,
    Map<String, dynamic>? json,
  }) {
    OrgVisibilityState _computeVisibility(OrgTree subtree) {
      var result = _kDefaultVisibilityState;
      if (json != null && subtree is OrgSection) {
        final title = subtree.headline.rawTitle;
        final fromJson = _orgVisibilityStateFromJson(json[title] as String?);
        result = fromJson ?? result;
      }
      return result;
    }

    final data = <OrgTree, OrgDataNode>{};
    root.visitSections((subtree) {
      data[subtree] =
          OrgDataNode(initialVisibility: _computeVisibility(subtree));
      return true;
    });
    return OrgDataNodeMap._(data);
  }

  factory OrgDataNodeMap.inherit(OrgDataNodeMap other) {
    final data = other._data.map((tree, node) =>
        MapEntry(tree, OrgDataNode(initialVisibility: node.visibility.value)));
    return OrgDataNodeMap._(data);
  }

  OrgDataNodeMap._(this._data);

  final Map<OrgTree, OrgDataNode> _data;

  OrgDataNode? nodeFor(OrgTree tree) => _data[tree];

  Set<OrgVisibilityState> get currentVisibility =>
      _data.values.map((e) => e.visibility.value).toSet();

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    for (final section in _data.keys.whereType<OrgSection>()) {
      final title = section.headline.rawTitle;
      if (title != null) {
        json[title] =
            _orgVisibilityStateToJson(_data[section]?.visibility.value);
      }
    }
    return json;
  }

  void dispose() {
    for (final node in _data.values) {
      node.dispose();
    }
  }

  void setAllVisibilities(OrgVisibilityState newState) {
    for (final node in _data.values) {
      node.visibility.value = newState;
    }
  }

  OrgSection? sectionWithTitle(String title) =>
      _data.keys.whereType<OrgSection?>().firstWhere(
            (section) => section!.headline.rawTitle == title,
            orElse: () => null,
          );

  OrgSection? sectionWithId(String id) =>
      _data.keys.whereType<OrgSection?>().firstWhere(
            (section) => section!.ids.contains(id),
            orElse: () => null,
          );

  OrgSection? sectionWithCustomId(String customId) =>
      _data.keys.whereType<OrgSection?>().firstWhere(
            (section) => section!.customIds.contains(customId),
            orElse: () => null,
          );
}

class OrgDataNode {
  OrgDataNode({required OrgVisibilityState initialVisibility})
      : visibility = ValueNotifier(initialVisibility);
  final ValueNotifier<OrgVisibilityState> visibility;

  void dispose() => visibility.dispose();
}

typedef OrgStateListener = Function(Map<String, dynamic>);

/// Control behavior of an Org Mode document widget. Not needed if you are using
/// the Org widget.
///
/// Place this in your widget hierarchy and fetch with [OrgController.of].
class OrgController extends StatefulWidget {
  /// Initialize the controller with existing data. Mostly useful for displaying
  /// a subsection of a parent document in a "narrowed" view; in such cases you
  /// should supply the [data] and [root] from the parent OrgController.
  OrgController.defaults(
    OrgControllerData data, {
    required OrgTree root,
    required Widget child,
    Key? key,
  }) : this._(
          child: child,
          root: root,
          inheritedNodeMap: data._nodeMap,
          searchQuery: data.searchQuery,
          hideMarkup: data.hideMarkup,
          key: key,
        );

  const OrgController({
    required Widget child,
    required OrgTree root,
    bool? hideMarkup,
    String? restorationId,
    Key? key,
  }) : this._(
          child: child,
          root: root,
          hideMarkup: hideMarkup,
          restorationId: restorationId,
          key: key,
        );

  const OrgController._({
    required this.child,
    required this.root,
    this.inheritedNodeMap,
    this.searchQuery,
    this.hideMarkup,
    this.entityReplacements = orgDefaultEntityReplacements,
    this.restorationId,
    Key? key,
  }) : super(key: key);

  /// The Org Mode document or section this controller will control
  final OrgTree root;

  /// The child widget
  final Widget child;

  /// Temporary data about the nodes in [root]
  final OrgDataNodeMap? inheritedNodeMap;

  /// A query for full-text search of the document
  final Pattern? searchQuery;

  /// Optionally hide some kinds of markup
  final bool? hideMarkup;

  /// A map of entity replacements, e.g. Agrave → À. See
  /// [orgDefaultEntityReplacements].
  final Map<String, String> entityReplacements;

  /// An ID for temporary state restoration. Supply a unique ID to ensure that
  /// temporary state such as scroll position is preserved as appropriate.
  final String? restorationId;

  static OrgControllerData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OrgControllerData>()!;

  @override
  _OrgControllerState createState() => _OrgControllerState();
}

class _OrgControllerState extends State<OrgController> with RestorationMixin {
  OrgTree get _root => widget.root;
  bool get _inheritNodeMap => widget.inheritedNodeMap != null;

  late OrgDataNodeMap _nodeMap;
  late Pattern _searchQuery;
  late bool _hideMarkup;
  Map<String, String> get _entityReplacements => widget.entityReplacements;

  @override
  void initState() {
    super.initState();
    if (_inheritNodeMap) {
      _nodeMap = OrgDataNodeMap.inherit(widget.inheritedNodeMap!);
    }
    _searchQuery = widget.searchQuery ?? _kDefaultSearchQuery;
    _hideMarkup = widget.hideMarkup ?? _kDefaultHideMarkup;
  }

  @override
  String? get restorationId =>
      _deriveRestorationId(widget.restorationId, 'org_controller');

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    if (!_inheritNodeMap) {
      final initialState = bucket?.read<String>(_kTransientStateNodeMapKey);
      final nodeMapJson = initialState == null
          ? null
          : json.decode(initialState) as Map<String, dynamic>;
      _nodeMap = OrgDataNodeMap.build(root: _root, json: nodeMapJson);
    }
  }

  @override
  void dispose() {
    _nodeMap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrgControllerData(
      root: widget.root,
      nodeMap: _nodeMap,
      searchQuery: _searchQuery,
      search: search,
      hideMarkup: _hideMarkup,
      entityReplacements: _entityReplacements,
      setHideMarkup: _setHideMarkup,
      cycleVisibility: _cycleVisibility,
      cycleVisibilityOf: _cycleVisibilityOf,
      restorationId: widget.restorationId,
      child: widget.child,
    );
  }

  /// Set the search query. Seciton visibility will be updated so that sections
  /// with hits are expanded and sections without will be collapsed.
  void search(Pattern query) {
    if (!patternEquals(_searchQuery, query)) {
      setState(() {
        _searchQuery = query;
        _updateVisibilityForQuery(query);
      });
      debugPrint('Querying: $query');
    }
  }

  void _updateVisibilityForQuery(Pattern query) {
    if (!emptyPattern(query)) {
      // Traverse tree from leaves to root in order to
      // a) prevent unnecessarily checking the same vertices twice
      // b) ensure correct visibility result
      bool _visit(OrgTree tree) {
        final childrenMatch = tree.sections.fold<bool>(false, (acc, section) {
          final match = _visit(section);
          return acc || match;
        });
        final anyMatch =
            childrenMatch || tree.contains(query, includeChildren: false);
        final newValue =
            anyMatch ? OrgVisibilityState.children : OrgVisibilityState.folded;
        final node = _nodeMap.nodeFor(tree);
        if (node != null) {
          // Document root is not in map, so its node will be null
          debugPrint(
              'Changing visibility; from=${node.visibility.value}, to=$newValue');
          node.visibility.value = newValue;
        }
        return anyMatch;
      }

      _visit(_root);
    }
  }

  void _cycleVisibility() {
    final currentStates = _nodeMap.currentVisibility;
    final newState = currentStates.length == 1
        ? _cycleGlobal(currentStates.single)
        : OrgVisibilityState.folded;
    debugPrint('Cycling global visibility; from=$currentStates, to=$newState');
    _nodeMap.setAllVisibilities(newState);
    _notifyState();
  }

  void _cycleVisibilityOf(OrgTree tree) {
    final visibilityListenable = _nodeMap.nodeFor(tree)!.visibility;
    final newVisibility =
        _cycleSubtree(visibilityListenable.value, tree.sections.isEmpty);
    final subtreeVisibility = _subtreeState(newVisibility);
    debugPrint(
        'Cycling subtree visibility; from=${visibilityListenable.value}, '
        'to=$newVisibility; subtree=$subtreeVisibility');
    tree.visitSections((subtree) {
      _nodeMap.nodeFor(subtree)!.visibility.value = subtreeVisibility;
      return true;
    });
    // Do this last because otherwise visitSections applies subtreeVisibility to
    // this root
    visibilityListenable.value = newVisibility;
    _notifyState();
  }

  void _notifyState() {
    final nodeMapString = json.encode(_nodeMap.toJson());
    bucket?.write<String>(_kTransientStateNodeMapKey, nodeMapString);
  }

  void _setHideMarkup(bool value) => setState(() => _hideMarkup = value);
}

class OrgControllerData extends InheritedWidget {
  const OrgControllerData({
    required Widget child,
    required this.root,
    required OrgDataNodeMap nodeMap,
    required this.searchQuery,
    required this.search,
    required bool hideMarkup,
    required Map<String, String> entityReplacements,
    required Function(bool) setHideMarkup,
    required this.cycleVisibility,
    required this.cycleVisibilityOf,
    String? restorationId,
    Key? key,
  })  : _nodeMap = nodeMap,
        _hideMarkup = hideMarkup,
        _entityReplacements = entityReplacements,
        _setHideMarkup = setHideMarkup,
        _restorationId = restorationId,
        super(key: key, child: child);

  /// The Org Mode document or section this controller will control
  final OrgTree root;

  final OrgDataNodeMap _nodeMap;

  /// Set the search query. Seciton visibility will be updated so that sections
  /// with hits are expanded and sections without will be collapsed.
  final Function(Pattern) search;

  /// A query for full-text search of the document
  final Pattern searchQuery;

  final bool _hideMarkup;

  final Map<String, String> _entityReplacements;

  final Function(bool) _setHideMarkup;

  /// Cycle the visibility of the entire document
  final void Function() cycleVisibility;

  /// Cycle the visibility of the specified subtree
  final void Function(OrgTree) cycleVisibilityOf;

  final String? _restorationId;

  /// Whether some kidns of markup should be hidden
  bool get hideMarkup => _hideMarkup;

  /// Optionally hide some kinds of markup
  set hideMarkup(bool value) => _setHideMarkup(value);

  /// Find the temporary data node for the given subtree
  OrgDataNode? nodeFor(OrgTree tree) => _nodeMap.nodeFor(tree);

  /// Find the section with the specified title
  OrgSection? sectionWithTitle(String title) =>
      _nodeMap.sectionWithTitle(title);

  /// Find the section with the specified ID
  OrgSection? sectionWithId(String id) => _nodeMap.sectionWithId(id);

  /// Find the section with the specified custom ID
  OrgSection? sectionWithCustomId(String customId) =>
      _nodeMap.sectionWithCustomId(customId);

  /// Find the section corresponding to [target], which may be one of
  ///
  /// - A section title link fragment like `*Foo bar`
  /// - A CUSTOM_ID link fragment like `#foo-bar`
  /// - An ID link like `id:abcd1234`
  ///
  /// The specified section may not exist in this tree, in which case the result
  /// will be null.
  ///
  /// If [target] is none of the above three types, an [Exception] will be
  /// thrown.
  OrgSection? sectionForTarget(String target) {
    if (isOrgLocalSectionUrl(target)) {
      return sectionWithTitle(parseOrgLocalSectionUrl(target));
    } else if (isOrgIdUrl(target)) {
      return sectionWithId(parseOrgIdUrl(target));
    } else if (isOrgCustomIdUrl(target)) {
      return sectionWithCustomId(parseOrgCustomIdUrl(target));
    } else {
      throw Exception(
          'Unknown target type: $target (was not a title or an ID)');
    }
  }

  /// Get the prettify-symbols-mode replacement with the given [name]. The
  /// result is obtained from [OrgController.entityReplacements].
  String? prettifyEntity(String name) => _entityReplacements[name];

  String? restorationIdFor(String name) =>
      _deriveRestorationId(_restorationId, name);

  @override
  bool updateShouldNotify(OrgControllerData oldWidget) =>
      root != oldWidget.root ||
      search != oldWidget.search ||
      searchQuery != oldWidget.searchQuery ||
      hideMarkup != oldWidget.hideMarkup ||
      !mapEquals(_entityReplacements, oldWidget._entityReplacements);
}

OrgVisibilityState _cycleGlobal(OrgVisibilityState state) {
  switch (state) {
    case OrgVisibilityState.folded:
      return OrgVisibilityState.contents;
    case OrgVisibilityState.contents:
      return OrgVisibilityState.subtree;
    case OrgVisibilityState.subtree:
    case OrgVisibilityState.children:
      return OrgVisibilityState.folded;
  }
}

OrgVisibilityState _cycleSubtree(OrgVisibilityState state, bool empty) {
  switch (state) {
    case OrgVisibilityState.folded:
      return OrgVisibilityState.children;
    case OrgVisibilityState.contents:
      return empty ? OrgVisibilityState.subtree : OrgVisibilityState.folded;
    case OrgVisibilityState.children:
      return empty ? OrgVisibilityState.folded : OrgVisibilityState.subtree;
    case OrgVisibilityState.subtree:
      return OrgVisibilityState.folded;
  }
}

OrgVisibilityState _subtreeState(OrgVisibilityState state) {
  switch (state) {
    case OrgVisibilityState.folded: // fallthrough
    case OrgVisibilityState.contents: // fallthrough
    case OrgVisibilityState.children:
      return OrgVisibilityState.folded;
    case OrgVisibilityState.subtree:
      return OrgVisibilityState.subtree;
  }
}

String? _deriveRestorationId(String? base, String name) =>
    base == null ? null : '$base/$name';
