import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:math';
import 'dart:ui' hide Size;

import 'package:flutter/material.dart';
import 'package:flutter_shapes/flutter_shapes.dart';
import 'package:logger/logger.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import "sketcher.dart";
import "stroke.dart";
import 'stroke_options.dart';

var dtwCC;
var logger = Logger();

class DrawingPage extends StatefulWidget {
  const DrawingPage({Key? key}) : super(key: key);

  @override
  _DrawingPageState createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  List<Stroke> lines = <Stroke>[];

  bool line1done = false;
  List<double> X1 = [];
  List<double> X2 = [];
  List<double> Y1 = [];
  List<double> Y2 = [];
  List<Double> P1 = [];
  List<Double> P2 = [];
  var distX = 0.0;
  var distY = 0.0;
  var distC = 0.0;
  String score = "0";

  List<Offset> positions = <Offset>[];

  Stroke? line;

  StrokeOptions options = StrokeOptions();

  StreamController<Stroke> currentLineStreamController =
      StreamController<Stroke>.broadcast();

  StreamController<List<Stroke>> linesStreamController =
      StreamController<List<Stroke>>.broadcast();

  Future<void> clear() async {
    setState(() {
      lines = [];
      line = null;
      X1 = [];
      X2 = [];
      Y1 = [];
      Y2 = [];
      P1 = [];
      P2 = [];
    });
  }

  Future<void> updateSizeOption(double size) async {
    setState(() {
      options.size = size;
    });
  }

  void onPointerDown(PointerDownEvent details) {
    options = StrokeOptions(
      simulatePressure: details.kind != PointerDeviceKind.stylus,
    );

    final box = context.findRenderObject() as RenderBox;
    final offset = box.globalToLocal(details.position);
    late final Point point;
    if (details.kind == PointerDeviceKind.stylus) {
      point = Point(
        offset.dx,
        offset.dy,
        (details.pressure - details.pressureMin) /
            (details.pressureMax - details.pressureMin),
      );
    } else {
      point = Point(offset.dx, offset.dy);
    }
    print(
        "down ${offset.dx},${offset.dy},${offset.direction},${offset.distance}");
    if (!line1done) {
      X1.add(offset.dx);
      Y1.add(offset.dy);
    } else {
      X2.add(offset.dx);
      Y2.add(offset.dy);
    }
    final points = [point];
    line = Stroke(points);
    currentLineStreamController.add(line!);
  }

  void onPointerMove(PointerMoveEvent details) {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.globalToLocal(details.position);
    late final Point point;
    if (details.kind == PointerDeviceKind.stylus) {
      point = Point(
        offset.dx,
        offset.dy,
        (details.pressure - details.pressureMin) /
            (details.pressureMax - details.pressureMin),
      );
    } else {
      point = Point(offset.dx, offset.dy);
    }
    //print("${DateTime.now().microsecondsSinceEpoch},${offset.dx},${offset.dy},${offset.direction},${offset.distance}");
    //line.points.line1.add(offset.dx.toInt());
    if (!line1done) {
      X1.add(offset.dx);
      Y1.add(offset.dy);
    } else {
      X2.add(offset.dx);
      Y2.add(offset.dy);
    }
    final points = [...line!.points, point];
    line = Stroke(points);
    currentLineStreamController.add(line!);
  }

  DTW dtw = DTW();

  void onPointerUp(PointerUpEvent details) {
    print("ON UP: line length ${lines.length}");
    lines = List.from(lines)..add(line!);
    if (!line1done) {
      line1done = true;
    } else {
      //print(X1);
      //print(X2);
      //print(Y1);
      //print(Y2);
      if (X1.length > 2 && X2.length > 2) {
        distX = dtw.distance(X1, X2);
        print("dtw = ${distX}");
      }
      if (Y1.length > 2 && Y2.length > 2) {
        distY = dtw.distance(Y1, Y2);
        print("dtw = ${distY}");
        distC = distX + distY;
        print(distC);
        setState(() {
          score = distC.toString();
        });
      }
      X1 = [];
      X2 = [];
      Y1 = [];
      Y2 = [];
      lines = [];
      line = null;

      line1done = false;
    }
    linesStreamController.add(lines);
  }

  Widget buildCurrentPath(BuildContext context) {
    return Listener(
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: onPointerUp,
      child: RepaintBoundary(
        child: Container(
            color: Colors.transparent,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: StreamBuilder<Stroke>(
                stream: currentLineStreamController.stream,
                builder: (context, snapshot) {
                  return CustomPaint(
                    painter: Sketcher(
                      lines: line == null ? [] : [line!],
                      options: options,
                    ),
                  );
                })),
      ),
    );
  }

  Widget buildAllPaths(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: StreamBuilder<List<Stroke>>(
          stream: linesStreamController.stream,
          builder: (context, snapshot) {
            return CustomPaint(
              painter: Sketcher(
                lines: lines,
                options: options,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildToolbar() {
    return Positioned(
        top: 40.0,
        right: 10.0,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Instructions",
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Text(
                "1: Draw a shape/path\n2: Trace Shape\nBetter Trace = Better Score\nHow low can you go?",
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
              ),
              const SizedBox(height: 20),
              const Text(
                "Score",
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(score),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              // const Text(
              //   'Size',
              //   textAlign: TextAlign.start,
              //   overflow: TextOverflow.ellipsis,
              //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              // ),
              // Slider(
              //     value: options.size,
              //     min: 1,
              //     max: 50,
              //     divisions: 100,
              //     label: options.size.round().toString(),
              //     onChanged: (double value) => {
              //           setState(() {
              //             options.size = value;
              //           })
              //         }),
              // const Text(
              //   'Thinning',
              //   textAlign: TextAlign.start,
              //   overflow: TextOverflow.ellipsis,
              //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              // ),
              // Slider(
              //     value: options.thinning,
              //     min: -1,
              //     max: 1,
              //     divisions: 100,
              //     label: options.thinning.toStringAsFixed(2),
              //     onChanged: (double value) => {
              //           setState(() {
              //             options.thinning = value;
              //           })
              //         }),
              // const Text(
              //   'Streamline',
              //   textAlign: TextAlign.start,
              //   overflow: TextOverflow.ellipsis,
              //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              // ),
              // Slider(
              //     value: options.streamline,
              //     min: 0,
              //     max: 1,
              //     divisions: 100,
              //     label: options.streamline.toStringAsFixed(2),
              //     onChanged: (double value) => {
              //           setState(() {
              //             options.streamline = value;
              //           })
              //         }),
              // const Text(
              //   'Smoothing',
              //   textAlign: TextAlign.start,
              //   overflow: TextOverflow.ellipsis,
              //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              // ),
              // Slider(
              //     value: options.smoothing,
              //     min: 0,
              //     max: 1,
              //     divisions: 100,
              //     label: options.smoothing.toStringAsFixed(2),
              //     onChanged: (double value) => {
              //           setState(() {
              //             options.smoothing = value;
              //           })
              //         }),
              // const Text(
              //   'Taper Start',
              //   textAlign: TextAlign.start,
              //   overflow: TextOverflow.ellipsis,
              //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              // ),
              // Slider(
              //     value: options.taperStart,
              //     min: 0,
              //     max: 100,
              //     divisions: 100,
              //     label: options.taperStart.toStringAsFixed(2),
              //     onChanged: (double value) => {
              //           setState(() {
              //             options.taperStart = value;
              //           })
              //         }),
              // const Text(
              //   'Taper End',
              //   textAlign: TextAlign.start,
              //   overflow: TextOverflow.ellipsis,
              //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              // ),
              // Slider(
              //     value: options.taperEnd,
              //     min: 0,
              //     max: 100,
              //     divisions: 100,
              //     label: options.taperEnd.toStringAsFixed(2),
              //     onChanged: (double value) => {
              //           setState(() {
              //             options.taperEnd = value;
              //           })
              //         }),
              const Text(
                'Clear',
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              buildClearButton(),
            ]));
  }

  Widget shapeThing(BuildContext context) {
    return GestureDetector(
      child: Container(
        color: Colors.transparent,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: CustomPaint(
            //painter: _MyPainter(positions: List<Offset>.from(positions))
            painter: _MyPainter(positions: positions.last)),
      ),
      onPanUpdate: _onPanUpdate,
    );
  }

  void _onPanUpdate(DragUpdateDetails update) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset position = renderBox.globalToLocal(update.globalPosition);
    if (positions.isNotEmpty &&
        (positions.last.dx - position.dx).abs() < 10 &&
        (positions.last.dy - position.dy).abs() < 10) {
      return;
    }
    if (positions.length > 50) {
      positions.removeAt(0);
    }
    setState(() {
      positions.add(position);
    });
  }

  Widget buildClearButton() {
    X1 = [];
    X2 = [];
    Y1 = [];
    Y2 = [];

    line1done = false;

    return GestureDetector(
      onTap: clear,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: const CircleAvatar(
            child: Icon(
          Icons.replay,
          size: 20.0,
          color: Colors.white,
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          buildAllPaths(context),
          buildCurrentPath(context),
          //shapeThing(context),
          buildToolbar()
        ],
      ),
    );
  }

  @override
  void dispose() {
    linesStreamController.close();
    currentLineStreamController.close();
    super.dispose();
  }
}

class DTW {
  double ubEuclidean(s1, s2) {
    return ED().edDistance(s1, s2);
  }

  double distance(List<double> s1, List<double> s2,
      {window,
      maxDist,
      maxStep,
      maxLengthDiff,
      penalty,
      psi,
      useC = false,
      usePruning = false,
      onlyUb = false}) {
    /*
    Dynamic Time Warping.
    This function keeps a compact matrix, not the full warping paths matrix.
    :param s1: First sequence
    :param s2: Second sequence
    :param window: Only allow for maximal shifts from the two diagonals smaller than this number.
        It includes the diagonal, meaning that an Euclidean distance is obtained by setting window=1.
    :param maxDist: Stop if the returned values will be larger than this value
    :param maxStep: Do not allow steps larger than this value
    :param maxLengthDiff: Return infinity if length of two series is larger
    :param penalty: Penalty to add if compression or expansion is applied
    :param psi: Psi relaxation parameter (ignore start and end of matching).
        Useful for cyclical series.
    :param useC: Use fast pure c compiled functions
    :param usePruning: Prune values based on Euclidean distance.
        This is the same as passing ub_euclidean() to max_dist
    :param onlyUb: Only compute the upper bound (Euclidean).
    Returns: DTW distance
    */

    var inf = "inf";

    if (useC) {
      if (dtwCC == null) {
        logger.e("C-library not available, using the Python version");
      } else {
        logger.d('distance fast');
      }
    }

    var r = s1.length;
    var c = s2.length;

    if (maxLengthDiff != null && (r - c).abs() > maxLengthDiff) {
      print('inside if');
      // return inf;
    }

    if (window == null) {
      window = max(r, c);
    }

    if (maxStep == null) {
      maxStep = inf;
    } else {
      maxStep *= maxStep;
    }

    if (usePruning || onlyUb) {
      maxDist = pow(ubEuclidean(s1, s2), 2);
      if (onlyUb) {
        return maxDist;
      }
    } else if (maxDist == null) {
      maxDist = inf;
    } else {
      maxDist *= maxDist;
    }

    if (penalty == null) {
      penalty = 0;
    } else {
      penalty *= penalty;
    }

    if (psi == null) {
      psi = 0;
    }

    var length = min(c + 1, (r - c).abs() + 2 * (window - 1) + 1 + 1 + 1);

    List dtw = ['d'];
    for (int i = 0; i < 2 * length - 1; i++) {
      dtw.add(inf);
    }

    var sc = 0;
    var ec = 0;
    var ecNext = 0;
    var smallerFound = false;

    for (int i = 0; i < psi + 1; i++) {
      dtw[i] = 0.0;
    }

    var skip = 0;
    var i0 = 1;
    var i1 = 0;
    var psiShortest = 100000.0;
    var d;

    for (int i = 0; i < r; i++) {
      var skipp = skip;
      skip = max(0, ((i - max(0, r - c) - window) + 1).toInt());
      i0 = 1 - i0;
      i1 = 1 - i1;
      for (int ii = (i1 * length).toInt(); ii < i1 * length + length; ii++) {
        dtw[ii] = inf;
      }
      var jStart = max(0, i - max(0, r - c) - window + 1);
      var jEnd = min(c, i + max(0, c - r) + window);

      if (sc > jStart) {
        jStart = sc;
      }
      smallerFound = false;
      ecNext = i;

      if (length == c + 1) {
        skip = 0;
      }
      if (psi != 0 && jStart == 0 && i < psi) {
        dtw[(i1 * length).toInt()] = 0;
      }
      for (int j = jStart.toInt(); j < jEnd; j++) {
        d = pow((s1[i] - s2[j]), 2);
        if (maxDist.runtimeType != String) {
          if (d > maxStep) {
            continue;
          }
        }
        assert(j + 1 - skip >= 0);
        assert(j - skipp >= 0);
        assert(j + 1 - skipp >= 0);
        assert(j - skip >= 0);

        var num1 = dtw[(i0 * length + j - skipp).toInt()];
        var num2;
        if (dtw[(i0 * length + j + 1 - skipp).toInt()].runtimeType != String) {
          num2 = dtw[(i0 * length + j + 1 - skipp).toInt()] + penalty;
        } else {
          num2 = dtw[(i0 * length + j + 1 - skipp).toInt()];
        }
        var num3;
        if (dtw[(i1 * length + j - skipp).toInt()].runtimeType != String) {
          num3 = dtw[(i1 * length + j - skipp).toInt()] + penalty;
        } else {
          num3 = dtw[(i1 * length + j - skipp).toInt()];
        }

        List<double> tempList = [];

        if (num1.runtimeType != String) {
          tempList.add(num1);
        }
        if (num2.runtimeType != String) {
          tempList.add(num2);
        }
        if (num3.runtimeType != String) {
          tempList.add(num3);
        }

        dtw[(i1 * length + j + 1 - skip).toInt()] = d + tempList.reduce(min);

        if (maxDist.runtimeType != String) {
          if (dtw[(i1 * length + j + 1 - skip).toInt()] > maxDist) {
            if (!smallerFound) {
              sc = j + 1;
            }
            if (j >= ec) {
              break;
            }
          } else {
            smallerFound = true;
            ecNext = j + 1;
          }
        }
      }
      ec = ecNext;
      if (psi != 0 && jEnd == s2.length && s1.length - 1 - i <= psi) {
        psiShortest = min(psiShortest, dtw[(i1 * length + length - 1).toInt()]);
      }
    }
    if (psi == 0) {
      d = dtw[(i1 * length + min(c, c + window - 1) - skip).toInt()];
    }
    if (maxDist.runtimeType != String) {
      if (maxDist != null && d > maxDist) {
        d = inf;
      }
    }
    d = sqrt(d);
    return d;
  }
}

class ED {
  double edDistance(List<double> s1, List<double> s2) {
    /* Euclidean distance between two sequences. Supports different lengths.
    If the two series differ in length, compare the last element of the shortest series
    to the remaining elements in the longer series. This is compatible with Euclidean
    distance being used as an upper bound for DTW.
    :param s1: Sequence of numbers
    :param s2: Sequence of numbers
    :return: Euclidean distance
    */
    var n = 0;
    var ub = 0.0;

    if (s1.length < s2.length) {
      n = s1.length;
    } else {
      n = s2.length;
    }

    for (var pair in zip([s1, s2])) {
      ub += pow((pair[0] - pair[1]), 2);
    }

    if (s1.length > s2.length) {
      var v2 = s2[n - 1];
      for (var v1 in s1.getRange(n, s1.length - 1)) {
        ub += pow((v1 - v2), 2);
      }
    } else if (s1.length < s2.length) {
      var v1 = s1[n - 1];
      for (var v2 in s2.getRange(n, s2.length - 1)) {
        ub += pow((v1 - v2), 2);
      }
    }

    return sqrt(ub);
  }
}

Iterable<List<T>> zip<T>(Iterable<Iterable<T>> iterables) sync* {
  if (iterables.isEmpty) return;
  final iterators = iterables.map((e) => e.iterator).toList(growable: false);
  while (iterators.every((e) => e.moveNext())) {
    yield iterators.map((e) => e.current).toList(growable: false);
  }
}

class _MyPainter extends CustomPainter {
  _MyPainter({required this.positions}) : super();

  //List<Offset> positions;
  Offset positions;

  @override
  bool shouldRepaint(_MyPainter oldDelegate) {
    return true;
    // return oldDelegate.positions.length != positions.length ||
    //     oldDelegate.positions[0] != positions[0];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    // for (Offset position in positions) {
    //   Shapes(canvas: canvas)
    //     ..paint = fill
    //     ..radius = 10
    //     ..center = position
    //     ..drawType(ShapeType.Star5);
    // }
    Shapes(canvas: canvas)
      ..paint = fill
      ..radius = 40
      ..center = positions
      ..drawType(ShapeType.Star5);
  }
}
