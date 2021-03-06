import java.util.*;
import java.util.function.Function;
import javafx.util.Pair;

/*
* Processing描画関数 =======================
 */

long lastMillisTime = -1;
final int SCREEN_WIDTH = 975;
final int SCREEN_HEIGHT = 350;
final int PIXEL_PER_METER = 5; // ピクセル数/m

final String mapImageFileName = "map.jpg";
PImage mapImage;
boolean isShowMap = true;
boolean isShowGrid = true;
boolean isShowAccelZ = false;


// プログラム開始時に一度だけ実行される処理
void settings() {
  size(SCREEN_WIDTH, SCREEN_HEIGHT);  // 画面サイズを設定
}

void setup() {
  background(255); // 背景色を設定
  noStroke(); // 図形の輪郭線を消す

  // マップ初期化
  mapImage = loadImage(mapImageFileName);
  mapImage.resize(SCREEN_WIDTH, SCREEN_HEIGHT);

  // ローバ初期化
  parentRover = new ParentRover(0, SCREEN_HEIGHT / 2, PIXEL_PER_METER * 10, 90);
  childrenRovers = new ArrayList<ChildRover>();
  for (int i = 0; i < CHILDREN_ROVERS_NUM; i++) {
    childrenRovers.add(new ChildRover(i + 1, SCREEN_HEIGHT / 2 + (i - CHILDREN_ROVERS_NUM / 2) * PIXEL_PER_METER * 10, PIXEL_PER_METER * 20, 90));
  }
}

final String COMMAND_TEXT = "[コマンド]\n" 
  + "　地形表示: m\n"
  + "　グリッド表示: g\n"
  + "　子機1加速度Z(コンソール): a\n";
final int COMMAND_TEXT_WIDTH = 200;

boolean m_isStop = false;

// setup()実行後に繰り返し実行される処理
void draw() {
  if (lastMillisTime == -1) {
    //　初回はテキストロードで時間がかかるので、それだけ先に処理させる
    text(COMMAND_TEXT, SCREEN_WIDTH - COMMAND_TEXT_WIDTH, 0, COMMAND_TEXT_WIDTH, SCREEN_HEIGHT);
    lastMillisTime = millis(); 
    return;
  }
  
  if (m_isStop) { return; }
  
  long currentMillisTime = millis(); 
  double deltaT = (currentMillisTime - lastMillisTime) / 1000.0;

  background(255); // 背景色を設定
  fill(0);
  text(COMMAND_TEXT, SCREEN_WIDTH - COMMAND_TEXT_WIDTH, 0, COMMAND_TEXT_WIDTH, SCREEN_HEIGHT);
  scale(1, -1); //上下反転(latは上向きが正)
  translate(0, -SCREEN_HEIGHT); //上下反転した分ずらす

  // マップ描画
  if (isShowMap) {
    tint(128, 200);
    image(mapImage, 0, 0);
    noTint();
  }
  if (isShowGrid) {
    stroke(0);
    strokeWeight(1);
    for (int i = 1; i < (int)(SCREEN_WIDTH / (7 * PIXEL_PER_METER)); i++) {
      line(i * 7 * PIXEL_PER_METER, 0, i * 7 * PIXEL_PER_METER, SCREEN_HEIGHT);
    }
    for (int i = 1; i < (int)(SCREEN_HEIGHT / (7 * PIXEL_PER_METER)); i++) {
      line(0, i * 7 * PIXEL_PER_METER, SCREEN_WIDTH, i * 7 * PIXEL_PER_METER);
    }
    noStroke();
  }

  // ミッション系実行
  double goalLineLng = SCREEN_WIDTH - parentRover.getGpsError() * PIXEL_PER_METER *  3;
  if (mode == Mode.STAY_PARENT_AND_CHILDREN) {
    // 初期位置は設定済みなのでそのまま探索開始 
    if (currentMillisTime < 5000) {
      switch(searchMode) { // 探索モードで行動変化
      case STRAIGHT:
        for (ChildRover childRover : childrenRovers) {
          childRover.targetCoord = new LatLng(SCREEN_HEIGHT / 2, SCREEN_WIDTH / 2);
          childRover.velocity = 8 * PIXEL_PER_METER;
        }
        break;
      case ZIGZAG:
        // 初期位置は固定にしてみる
        double[][] initPositionsRatio = {{0.1, 0.9}, {0.1, 0.1}, {0.5, 0.5}, {0.95, 0.1}, {0.9, 0.9}};
        for (int i = 0; i < childrenRovers.size(); ++i) {
          ChildRover childRover = childrenRovers.get(i);
          childrenRovers.get(i).targetCoord = new LatLng(SCREEN_HEIGHT * initPositionsRatio[i][0], SCREEN_WIDTH * initPositionsRatio[i][1]);
          childRover.velocity = 8 * PIXEL_PER_METER;
        }
        break;
      }
      mode = Mode.CHILDREN_SERACH;
    }
  } else if (mode == Mode.CHILDREN_SERACH) {
    switch(searchMode) { // 探索モードで行動変化
    case STRAIGHT:
      for (ChildRover childRover : childrenRovers) {
        if (childRover.getCoord().lng > goalLineLng && !finishedSearchRovers.contains(childRover)) {
          finishedSearchRovers.add(childRover);
          childRover.velocity = 0;
        }
      }

      // 探索終了個体でモード変更
      if (finishedSearchRovers.size() == CHILDREN_ROVERS_NUM) {
        mode = Mode.SEND_CHILDREN_DATA;
      }

      break;
    case ZIGZAG:
      Iterator<RoverBase> iterator = finishedSearchRovers.iterator();
      while (iterator.hasNext()) {
        RoverBase childRover = iterator.next();
        ArrayList<Pair<LatLng, LatLng>> positionsSet = new ArrayList<Pair<LatLng, LatLng>>();
        ArrayList<SearchRecord> records = new ArrayList<SearchRecord>();
        for (ChildRover cr: childrenRovers) {
          if (cr == childRover) { continue; }
          positionsSet.add(new Pair<LatLng, LatLng>(cr.getCoord(), cr.targetCoord));
          records.addAll(cr.getRecords());
        }

        int angleNum = 36;
        int angleStart = (int)random(36);
        int distanceNum = 3;
        int distanceDiff = 30;
        LatLng coord = childRover.getCoord();

        double minBoundingSearchRecordsNum = 9999;
        LatLng minBoundingNewTarget = null;
        
        for (int i = 0; i < angleNum; ++i) {
          for (int j = distanceNum; j >= 1 ; --j) {
            double newLat = coord.lat + sin(radians(360.0 / angleNum * (i * 11 + angleStart))) * distanceDiff * j * PIXEL_PER_METER;
            double newLng = coord.lng + cos(radians(360.0 / angleNum * (i * 11 + angleStart))) * distanceDiff * j * PIXEL_PER_METER;
            LatLng newTarget = new LatLng(newLat, newLng);
            if (!(newLat > 0 && newLat < SCREEN_HEIGHT && newLng > 0 && newLng < SCREEN_WIDTH)) { continue; }
            
            ArrayList<Pair<LatLng, LatLng>> collidedPair = getCollidedOtherRoverTargetPath(coord, newTarget, positionsSet);
            
            if (collidedPair.isEmpty()) {
              // DEBUG
              //stroke(255, 0, 0);
              //line((float)(coord.lng + diffX - diffY), (float)(coord.lat + diffY + diffX), (float)(newTarget.lng - diffX - diffY), (float)(newTarget.lat - diffY + diffX));
              //line((float)(coord.lng + diffX + diffY), (float)(coord.lat + diffY - diffX), (float)(newTarget.lng - diffX + diffY), (float)(newTarget.lat - diffY - diffX));
              //m_isStop = true;
                
              ArrayList<SearchRecord> boundingRecords = findBoundingRecord(newTarget, records);
              if (boundingRecords.size() < minBoundingSearchRecordsNum) {
                minBoundingSearchRecordsNum = boundingRecords.size();
                minBoundingNewTarget = newTarget;
              }
            }
          }
        }

        if (minBoundingNewTarget != null) {
          childRover.targetCoord = minBoundingNewTarget;
          childRover.velocity = 0;
          childRover.targetVelocity = new Double(8 * PIXEL_PER_METER);
          iterator.remove();
        }
      }
      
      if (currentMillisTime > 120 * 1000) {
        for (ChildRover childRover: childrenRovers) {
          childRover.targetCoord = null;
          childRover.velocity = 0;
          childRover.targetVelocity = null;
        }
        mode = Mode.SEND_CHILDREN_DATA;
      }
      break;
    }
  } else if (mode == Mode.SEND_CHILDREN_DATA) {
    // 省略(実機では通信などでデータを送る必要がある)
    mode = Mode.CARRY_PARENT;
  } else if (mode == Mode.CARRY_PARENT) {
    switch(pathfindingMethod) {
    case ACTOR_CRITIC:
      if (currentMillisTime - lastTrainTime > 0 && trainCount < 10000) {
        System.out.println("train: " + trainCount + "/10000");
        //train(); // 削除
        trainCount++;

        lastTrainTime = currentMillisTime;
      }
      break;
    case DIJKSTRA:
      dijkstra();
      break;
    }
  }

  // ローバー更新
  parentRover.update(deltaT);
  for (ChildRover childRover : childrenRovers) {
    childRover.update(deltaT);
  }

  // ローバー描画
  drawRover(parentRover, 100, 0, 0);
  for (int i = 0; i < childrenRovers.size(); i++) {
    ChildRover childRover = childrenRovers.get(i);
    drawRover(childRover, 0, 50 + 20 * i, 0);
    if (i == 0 && isShowAccelZ) {
      System.out.println("AccelZ: " + childRover.getAccelZ());
    }
    
    // targetCoord表示
    stroke(0, 50 + 20 * i, 0);
    strokeWeight(10);
    if (childRover.targetCoord != null) {
      point((float)childRover.targetCoord.lng, (float)childRover.targetCoord.lat);
    }

    // 探索記録表示
    noFill();
    ArrayList<SearchRecord> records = childRover.getRecords();
    for (SearchRecord record : records) {
      float gpsError = (float)childRover.getGpsError();
      strokeWeight(sqrt((float)record.accelZVariance * 100));
      stroke(0, 50 + 20 * i, 0, 100);
      circle((float)record.lng, (float)record.lat, gpsError * PIXEL_PER_METER * 2);

      strokeWeight(1);
      line((float)record.lng, (float)record.lat, (float)record.lng + sin(radians((float)record.azimuth)) / 2 * gpsError * PIXEL_PER_METER, (float)record.lat + cos(radians((float)record.azimuth)) / 2 * gpsError * PIXEL_PER_METER);
    }
    noStroke();
  }

  // 学習記録描画
  if (!stateHistories.isEmpty()) {
    ArrayList<Pair<LatLng, Float>> history = stateHistories.get(stateHistories.size() - 1);
    int r = 255;
    for (int j = 0; j < history.size(); j++) {
      Pair<LatLng, Float> e = history.get(j);
      LatLng latLng = e.getKey();
      strokeWeight(4);
      stroke(r / history.size() * (j + 1), 0, 0, 100);
      point((float)latLng.lng, (float)latLng.lat);
      strokeWeight(1);
      line((float)latLng.lng, (float)latLng.lat, (float)latLng.lng + sin(radians(e.getValue())) * 5, (float)latLng.lat + cos(radians(e.getValue())) * 5);
    }
  }

  lastMillisTime = currentMillisTime;
}

void drawRover(RoverBase rover, int r, int g, int b) {
  fill(r, g, b);
  pushMatrix();
  LatLng latLng = rover.getPosition();
  translate((float)latLng.lng, (float)latLng.lat);
  rotate(-radians((float)rover.getAngle() + 180));
  scale(0.2);
  rect(-30, -15, 60, 30); //body
  triangle(-20, -15, 20, -15, 0, -25); //body front
  rect(-40, -25, 10, 50); //tire left
  rect(30, -25, 10, 50); //tire right
  popMatrix();
}

/*
* Processing操作関数 =======================
 */

void keyPressed() {
  if (key == 'M' || key == 'm') {  // Mキーに反応
    isShowMap = !isShowMap;
  } else if (key == 'G' || key == 'g') {
    isShowGrid = !isShowGrid;
  } else if (key == 'A' || key == 'a') {
    isShowAccelZ = !isShowAccelZ;
  }
}

/*
* ミッション関連 =======================
 */

enum Mode { // 全体のモード
  STAY_PARENT_AND_CHILDREN, //親機子機待機
    CHILDREN_SERACH, // 子機探索
    SEND_CHILDREN_DATA, // 探索データの送信
    CARRY_PARENT, // 親機学習&移動
    CALL_CHILDREN_AFTER_CARRY,
};
Mode mode = Mode.STAY_PARENT_AND_CHILDREN;

enum PathfindingMethod {
  ACTOR_CRITIC, 
    DIJKSTRA
}
PathfindingMethod pathfindingMethod = PathfindingMethod.DIJKSTRA;

enum SearchMode {
  STRAIGHT, // 直進
    ZIGZAG // ジグザグ
};
SearchMode searchMode = SearchMode.ZIGZAG;
HashSet<RoverBase> finishedSearchRovers = new HashSet<RoverBase>(); // 探索が終了したローバ

class SearchRecord { // 探索のモード
  int id; 
  // 操作に関する記録(調査事項によって変える)
  double lat;
  double lng;
  double accelZVariance;
  double azimuth;
  Date atTime; //時分秒のみ

  SearchRecord(int id, double lat, double lng, double accelZVariance, double azimuth, Date atTime) {
    this.id = id;
    this.lat = lat;
    this.lng = lng;
    this.accelZVariance = accelZVariance;
    this.azimuth = azimuth;
    this.atTime = atTime;
  }
}

/*
* シミュ用個体 =======================
 */

class RoverBase {
  // ローバプログラム関連
  protected int id;
  private LatLng latLng; //y
  public double targetAzimuth;
  public LatLng targetCoord = null;
  public double velocity; //速度 
  public Double targetVelocity = null;
  private double azimuth;
  private double accelZ;

  // シミュレーション上関連
  private final double rotateAbility = 50; // 回転速度deg/sec
  private final double accelAbility = 1; // 加速度m/sec^2
  private final double gpsError = 5; // GPS誤差 m
  private float lastMapColor;
  private float azimuthUpdateElipsedTime = 0;

  RoverBase(int id, double lat, double lng, double azimuth) {
    this.id = id;
    this.latLng = new LatLng(lat, lng);
    this.velocity = 0;
    this.azimuth = azimuth;
    this.targetAzimuth = azimuth;
    this.lastMapColor = getMapColor();
    this.accelZ = 1.0;
  }

  LatLng getPosition() { // 位置情報真値
    return latLng;
  }

  LatLng getCoord() { // 位置情報(誤差含む)
    float pixelError = (float)gpsError * PIXEL_PER_METER;
    return new LatLng(latLng.lat + (- pixelError + random(2 * pixelError)) * random(1.0), latLng.lng + (- pixelError + random(2 * pixelError)) * random(1.0));
  }

  double getAngle() { // 方位角情報真値
    return azimuth;
  }

  double getAzimuth() { // 方位角情報(誤差含む)
    return azimuth - 25.0 + random(50.0);
  }

  double getAccelZ() { // 加速度情報(誤差含む)
    return accelZ + 0.05 - random(0.1);
  }

  private float getMapColor() { // マップから自分の座標の色情報を取得する
    PImage croped = mapImage.get((int)latLng.lng - 10, (int)latLng.lat - 10, 20, 20);
    int redAve = 0;
    for (int i = 0; i < croped.pixels.length; i++) {
      redAve += red(croped.pixels[i]);
    }
    return redAve /(croped.pixels.length * 10.0);
  }

  double getGpsError() {
    return gpsError;
  }

  boolean isOnTargetPosition() {
    LatLng coord = getCoord();
    double latDiff = coord.lat - targetCoord.lat;
    double lngDiff = coord.lng - targetCoord.lng;
    return latDiff * latDiff + lngDiff * lngDiff < gpsError * gpsError * PIXEL_PER_METER * PIXEL_PER_METER * 1.75;
  }

  void update(double deltaT) {
    // 速度制御
    if (targetVelocity != null) {
      if (targetVelocity - velocity > accelAbility) {
        velocity += accelAbility;
      } else if (targetVelocity - velocity < -accelAbility) { 
        velocity -= accelAbility;
      } else {
        velocity = targetVelocity;
      }
    }
    // 回転制御
    if (targetCoord != null) {
      LatLng coord = getCoord();
      float latDiff = (float)(targetCoord.lat - coord.lat);
      float lngDiff = (float)(targetCoord.lng - coord.lng);
      targetAzimuth = degrees(atan2(lngDiff, latDiff));
    }

    double angleDiff = targetAzimuth - azimuth;
    while (angleDiff > 180) {
      angleDiff -= 360;
    }
    while (angleDiff < -180) {
      angleDiff += 360;
    }
    double deltaRotateAbility = rotateAbility * deltaT;
    if (angleDiff < deltaRotateAbility && angleDiff > -deltaRotateAbility) {
      azimuth = targetAzimuth;
    } else if (angleDiff > 0) {
      azimuth += deltaT * rotateAbility;
    } else {
      azimuth -= deltaT * rotateAbility;
    }
    // 移動制御
    latLng.lat += cos(radians((float)getAzimuth())) * velocity * deltaT;
    latLng.lng += sin(radians((float)getAzimuth())) * velocity * deltaT;

    // 範囲制限
    //if (latLng.lat < gpsError * PIXEL_PER_METER * 2) {
    //  latLng.lat = gpsError * PIXEL_PER_METER * 2;
    //} else if (latLng.lat > SCREEN_HEIGHT - gpsError * PIXEL_PER_METER * 2) {
    //  latLng.lat = SCREEN_HEIGHT - gpsError * PIXEL_PER_METER * 2;
    //}

    //if (latLng.lng < gpsError * PIXEL_PER_METER * 2) {
    //  latLng.lng = gpsError * PIXEL_PER_METER * 2;
    //} else if (latLng.lng > SCREEN_WIDTH - gpsError * PIXEL_PER_METER * 2) {
    //  latLng.lng = SCREEN_WIDTH - gpsError * PIXEL_PER_METER * 2;
    //}

    // センサ値更新
    azimuthUpdateElipsedTime += deltaT;
    if (azimuthUpdateElipsedTime > 0.05) {
      float currentMapColor = getMapColor();
      accelZ = 1.0 + currentMapColor - lastMapColor;
      lastMapColor = currentMapColor;
      azimuthUpdateElipsedTime = 0;
    }
  }
}

class ParentRover extends RoverBase {
  ParentRover(int id, double lat, double lng, double azimuth) {
    super(id, lat, lng, azimuth);
  }
}

class ChildRover extends RoverBase {
  private ArrayList<SearchRecord> records = new ArrayList<SearchRecord>();
  private double lastRecordElipsedTime = 0;
  private ArrayList<Double> azimuthRecords = new ArrayList<Double>();
  private ArrayList<Double> accelZRecords = new ArrayList<Double>();
  private LatLng trueTargetCoord = null;
  private boolean isColliedOtherRoverPath = false;
  private float avoidColliedTargetDiff = 0;
  private double checkColliedTimer = 0;

  ChildRover(int id, double lat, double lng, double azimuth) {
    super(id, lat, lng, azimuth);
  }

  @Override void update(double deltaT) {
    // 調査記録
    if (mode == Mode.CHILDREN_SERACH) {
      if (targetCoord == null) {
        return;
      }

      LatLng coord = getCoord();

      // 衝突回避
      checkColliedTimer += deltaT;
      if (checkColliedTimer > 1) {
        checkColliedTimer = 0;
        if (trueTargetCoord == null) {
          trueTargetCoord = targetCoord;
        }
        ArrayList<Pair<LatLng, LatLng>> positionsSet = new ArrayList<Pair<LatLng, LatLng>>();
        for (ChildRover cr: childrenRovers) {
          if (cr == this) { continue; }
          positionsSet.add(new Pair<LatLng, LatLng>(cr.getCoord(), cr.targetCoord));
        }
        ArrayList<Pair<LatLng, LatLng>> collidedPair = getCollidedOtherRoverTargetPath(coord, trueTargetCoord, positionsSet);
        if (!collidedPair.isEmpty()) {
          // ペアに左肩/右肩下がりがあるか
          boolean isExistOthersPathOnLeft = false;
          boolean isExistOthersPathOnRight = false;
          double minPathLength = 999999;
          // 一番近いペアが右肩さがりにあるか
          boolean isNearestPairOnRight = true;
          
          for (Pair<LatLng, LatLng> pair : collidedPair) {
            LatLng key = pair.getKey();
            LatLng value = pair.getValue();

            // ペアの端点のうち一番近い方
            LatLng nearestPairPoint = null;

            if (value != null) {
              double diffRoverCoordLat = coord.lat - key.lat;
              double diffRoverCoordLng = coord.lng - key.lng;
              double diffTargetCoordLat = coord.lat - value.lat;
              double diffTargetCoordLng = coord.lng - value.lng;

              nearestPairPoint = (diffRoverCoordLat * diffRoverCoordLat + diffRoverCoordLng * diffRoverCoordLng) < (diffTargetCoordLat * diffTargetCoordLat + diffTargetCoordLng * diffTargetCoordLng) ? key : value;

              double distance = linePointMinDistance(coord, trueTargetCoord, nearestPairPoint);
              if (distance < minPathLength) {
                minPathLength = distance;
                isNearestPairOnRight = isExistPointRight(coord, trueTargetCoord, nearestPairPoint);
              }
            } else {
              nearestPairPoint = key;

              double distance = pointDistance(coord, key);
              if (distance < minPathLength) {
                minPathLength = distance;
                isNearestPairOnRight = isExistPointRight(coord, trueTargetCoord, key);
              }
            }

            if (isExistPointRight(coord, trueTargetCoord, nearestPairPoint)) {
              isExistOthersPathOnRight = true;
            } else {
              isExistOthersPathOnLeft = true;
            }
          }
          
          if (isNearestPairOnRight) {
            double diffLat = trueTargetCoord.lat - coord.lat;
            double diffLng = trueTargetCoord.lng - coord.lng;
            avoidColliedTargetDiff = avoidColliedTargetDiff < 90 ? avoidColliedTargetDiff + 1 : avoidColliedTargetDiff;
            float angle = radians(degrees(atan2((float)diffLat, (float)diffLng)) + (isExistOthersPathOnRight ? -avoidColliedTargetDiff : avoidColliedTargetDiff));
            targetCoord = new LatLng(coord.lat + sin(angle) * 9999, coord.lng + cos(angle) * 9999);
          }

          if (isExistOthersPathOnLeft && isExistOthersPathOnRight) {
            velocity = targetVelocity / 2;
          }
          isColliedOtherRoverPath = true;
        } else {
          targetCoord = trueTargetCoord;
          isColliedOtherRoverPath = false;
        }
      }
      
      if (!isColliedOtherRoverPath && isOnTargetPosition()) {
        targetCoord = null;
        trueTargetCoord = null;
        avoidColliedTargetDiff = 0;
        velocity = 0;
        finishedSearchRovers.add(this);
      }
      
      lastRecordElipsedTime += deltaT;
      
      if (lastRecordElipsedTime > 0.5) { 
        float accelZVariance = variance(accelZRecords);
        records.add(new SearchRecord(id, coord.lat, coord.lng, accelZVariance, mean(azimuthRecords), new Date()));
        // 手前いくつかの記録も更新する
        int maxUpdateRecordCount = 5; //いくつのデータを更新するか
        int weightSourceRecord = 2; //現在の記録の重み
        int updateRecordCount = records.size() > maxUpdateRecordCount  ? maxUpdateRecordCount : records.size() - 1;
        for (int i = 0; i < updateRecordCount; i++) {
          SearchRecord updateTarget = records.get(records.size() - i - 1);
          updateTarget.accelZVariance = (accelZVariance * (maxUpdateRecordCount - i) + updateTarget.accelZVariance * weightSourceRecord) / (maxUpdateRecordCount - i + weightSourceRecord);
        }

        lastRecordElipsedTime = 0;
      }
      azimuthRecords.add(new Double(getAzimuth()));
      accelZRecords.add(new Double(getAccelZ()));
      if (azimuthRecords.size() > 20) { // MAXで20の履歴にする
        azimuthRecords.remove(0);
        accelZRecords.remove(0);
      }
    }

    super.update(deltaT);
  }

  ArrayList<SearchRecord> getRecords() {
    return records;
  }
}

ParentRover parentRover;
ArrayList<ChildRover> childrenRovers;
final int CHILDREN_ROVERS_NUM = 5;

/*
* 経路探索 =======================
 */

class World {
  private ArrayList<SearchRecord> records = null;
  public int update(Action action, int stateId) {
    int lngNo = (int)floor((float)stateId / Action.SIZE.ordinal()) % widthBlockNum;
    int latNo = floor((float)stateId / (Action.SIZE.ordinal() * widthBlockNum));

    switch(action) {
    case UP:
      latNo += 1;
      break;
    case UPPER_RIGHT:
      latNo += 1;
      lngNo += 1;
      break;
    case RIGHT:
      lngNo += 1;
      break;
    case BOTTOM_RIGHT:
      latNo -= 1;
      lngNo += 1;
      break;
    case BOTTOM:
      latNo -= 1;
      break;
    case BOTTOM_LEFT:
      latNo -= 1;
      lngNo -= 1;
      break;
    case LEFT:
      lngNo -= 1;
      break;
    case UPPER_LEFT:
      latNo += 1;
      lngNo -= 1;
      break;
    default:
      break;
    }

    return getState(latNo, lngNo, action);
  }

  public Set<Integer> getActionsAvailableAtState(int newState, Action oldAction) {
    HashSet<Action> actionSet;
    int lngNo = (int)floor((float)newState / Action.SIZE.ordinal()) % widthBlockNum;
    int latNo = floor((float)newState / (Action.SIZE.ordinal() * widthBlockNum));

    actionSet = new HashSet<Action>();

    if (oldAction != Action.UP) {
      actionSet.add(Action.BOTTOM);
    }
    if (oldAction != Action.BOTTOM) {
      actionSet.add(Action.UP);
    }
    actionSet.add(Action.BOTTOM_RIGHT);
    actionSet.add(Action.RIGHT);
    actionSet.add(Action.UPPER_RIGHT);

    if (lngNo == 0) { //左端
      actionSet.remove(Action.UPPER_LEFT);
      actionSet.remove(Action.LEFT);
      actionSet.remove(Action.BOTTOM_LEFT);
      if (actionSet.isEmpty()) { // 空なら右回りで一つ足す
        actionSet.add(Action.UP);
      }
    }
    if (latNo == heightBlockNum - 1) { //上端
      actionSet.remove(Action.UPPER_LEFT);
      actionSet.remove(Action.UP);
      actionSet.remove(Action.UPPER_RIGHT);
      if (actionSet.isEmpty()) { // 空なら右回りで一つ足す
        actionSet.add(Action.RIGHT);
      }
    }
    if (lngNo == widthBlockNum - 1) { //右端
      actionSet.remove(Action.UPPER_RIGHT);
      actionSet.remove(Action.RIGHT);
      actionSet.remove(Action.BOTTOM_RIGHT);
      if (actionSet.isEmpty()) { // 空なら右回りで一つ足す
        actionSet.add(Action.BOTTOM);
      }
    }
    if (latNo == 0) { //下端
      actionSet.remove(Action.BOTTOM_LEFT);
      actionSet.remove(Action.BOTTOM);
      actionSet.remove(Action.BOTTOM_RIGHT);
      if (actionSet.isEmpty()) { // 空なら右回りで一つ足す
        actionSet.add(Action.LEFT);
      }
    }

    HashSet<Integer> integerSet = new HashSet<Integer>();
    for (Action a : actionSet) {
      integerSet.add(a.ordinal());
    }

    return integerSet;
  }

  public int getState(RoverBase rover, Action action) {
    LatLng latLng = rover.getCoord(); 
    return getState(latLng, action);
  }
  public int getState(LatLng latLng, Action action) {
    int lngNo = floor((float)latLng.lng / oneBlockEdge);
    int latNo = floor((float)latLng.lat / oneBlockEdge);
    return getState(latNo, lngNo, action);
  }
  public int getState(int latNo, int lngNo, Action action) {
    int stateId = action.ordinal() + lngNo * Action.SIZE.ordinal() + latNo * widthBlockNum * Action.SIZE.ordinal();
    return stateId;
  }

  public void setSearchRecords(ArrayList<SearchRecord> records) {
    this.records = records;
  }

  public LatLng stateToLatLng(int stateId) {
    int lngNo = (int)floor((float)stateId / Action.SIZE.ordinal()) % widthBlockNum;
    int latNo = floor((float)stateId / (Action.SIZE.ordinal() * widthBlockNum));
    double lng = lngNo * oneBlockEdge + (oneBlockEdge / 2);
    double lat = latNo * oneBlockEdge + (oneBlockEdge / 2);
    return new LatLng(lat, lng);
  }

  public float actionToDegree(Action action) {
    return 45.0 * action.ordinal();
  }

  public boolean isGoal(int stateId) {
    int lngNo = (int)floor((float)stateId / Action.SIZE.ordinal()) % widthBlockNum;
    return lngNo == widthBlockNum - 1;
  }

  public Function<Integer, Double> getValueFunction() {
    return new Function<Integer, Double>() { // 参考: https://github.com/chen0040/java-reinforcement-learning/blob/f85cb03e5d16512f6bb9e126fa940b9e49d5bde7/src/main/java/com/github/chen0040/rl/learning/actorcritic/ActorCriticLearner.java#L85
      @Override
        public Double apply(Integer stateId) {
        Action action = Action.fromInteger(stateId % Action.SIZE.ordinal());
        LatLng latLng = stateToLatLng(stateId);
        ArrayList<SearchRecord> boundingRecords = findBoundingRecord(latLng, records);

        if (boundingRecords.isEmpty()) {
          //return new Double(latLng.lng <= 100 ? 0 : -1);
          return new Double(-1);
        }

        double weightSum = 0;
        double accelZVarianceWeightSum = 0;
        double currentAzimuth = actionToDegree(action);
        for (SearchRecord record : boundingRecords) {
          double azimuthDiff = record.azimuth - currentAzimuth;
          while (azimuthDiff < -180) {
            azimuthDiff += 360;
          }
          while (azimuthDiff > 180) {
            azimuthDiff -= 360;
          }
          float weight = 180 - abs((float)azimuthDiff);
          accelZVarianceWeightSum += record.accelZVariance * weight;
          weightSum += weight;
        }

        double weightAve = weightSum / accelZVarianceWeightSum;
        return new Double(weightAve);
      }
    };
  }
}

// 行動
enum Action {
  UP, 
    UPPER_RIGHT, 
    RIGHT, 
    BOTTOM_RIGHT, 
    BOTTOM, 
    BOTTOM_LEFT, 
    LEFT, 
    UPPER_LEFT, 
    SIZE;

  public static Action fromInteger(int x) {
    switch(x) {
    case 0:
      return UP;
    case 1:
      return UPPER_RIGHT;
    case 2:
      return RIGHT;
    case 3:
      return BOTTOM_RIGHT;
    case 4:
      return BOTTOM;
    case 5:
      return BOTTOM_LEFT;
    case 6:
      return LEFT;
    case 7:
      return UPPER_LEFT;
    }
    System.out.println("There is no match action! no: " + x);
    return null;
  }
}

class Move {
  int oldState;
  int newState;
  Action action;
  double reward;

  public Move(int oldState, Action action, int newState, double reward) {
    this.oldState = oldState;
    this.newState = newState;
    this.reward = reward;
    this.action = action;
  }
}

// 強化学習のstate数を決める
final int oneBlockEdge = (5 * PIXEL_PER_METER);
final int widthBlockNum = SCREEN_WIDTH / oneBlockEdge;
final int heightBlockNum = SCREEN_HEIGHT / oneBlockEdge;

int trainCount = 0;
long lastTrainTime = 0;

ArrayList<ArrayList<Pair<LatLng, Float>>> stateHistories = new ArrayList<ArrayList<Pair<LatLng, Float>>>();

int stateCount = widthBlockNum * heightBlockNum * Action.SIZE.ordinal(); // マップを7m正方形で分割したのがstateの数。7mなのはGPS半径5mの誤差円の内接正方形の一辺。
int actionCount = Action.SIZE.ordinal(); // 0: 上 1: 右上 で8方向

final public class CoordinateComparator implements Comparator<Pair<Double, LatLng>> {
  public int compare(Pair<Double, LatLng> obj1, Pair<Double, LatLng> obj2) {
    Pair<Double, LatLng> p1 = (Pair<Double, LatLng>)obj1;
    Pair<Double, LatLng> p2 = (Pair<Double, LatLng>)obj2;

    if (p1.getKey() > p2.getKey()) {
      return 1;
    } else {
      return -1;
    }
  }
}

int latLng2Int(LatLng latLng) {
  return (int)(floor((float)latLng.lng / oneBlockEdge) * heightBlockNum + (int)floor((float)latLng.lat / oneBlockEdge));
}

void dijkstra() {
  Double[] cost = new Double[widthBlockNum * heightBlockNum];
  Double[] weightSum = new Double[widthBlockNum * heightBlockNum];
  Double[] costSum = new Double[widthBlockNum * heightBlockNum];
  Arrays.fill(cost, (double)0.0);
  Arrays.fill(weightSum, (double)0.0);
  Arrays.fill(costSum, (double)0.0);
  Double[] sigma = {(double)0.1, (double)0.1};
  for (ChildRover rover : childrenRovers) {
    for (SearchRecord record : rover.getRecords()) {
      int h = floor((float)record.lat / oneBlockEdge), w = floor((float)record.lng / oneBlockEdge);
      for (int i = -1; i < 2; i++) {
        for (int j = -1; j < 2; j++) {
          if (0 <= w + i && w + i < widthBlockNum && 0 <= h + j && h + j < heightBlockNum) {
            double weight = (1 - bivariateNormalDistribution((w + i + 0.5) * oneBlockEdge, (h + j + 0.5) * oneBlockEdge, new Double[]{record.lng, record.lat}, sigma));
            weightSum[(w + i) * heightBlockNum + h + j] += weight;
            costSum[(w + i) * heightBlockNum + h + j] += weight * record.accelZVariance;
          }
        }
      }
    }
  }
  for (int i = 0; i < widthBlockNum; i++) {
    for (int j = 0; j < heightBlockNum; j++) {
      if (weightSum[i * heightBlockNum + j] != 0.0) {
        cost[i * heightBlockNum + j] = costSum[i * heightBlockNum + j] / weightSum[i * heightBlockNum + j] * 100;
      } else {
        cost[i * heightBlockNum + j] = (double)1000;
      }
    }
  }
  println(widthBlockNum, heightBlockNum);
  // println(Arrays.deepToString(cost));
  for (int i = 0; i < heightBlockNum; i++) {
    for (int j = 0; j < widthBlockNum; j++) {
      print(String.format("%4d", Math.round(cost[i + j * heightBlockNum])), ", ");
    }
    println();
  }
  Queue qu = new PriorityQueue<Pair<Double, LatLng>>(new CoordinateComparator());
  qu.add(new Pair<Double, LatLng>((double)0.0, parentRover.getPosition()));
  Integer[] prevIdx = new Integer[widthBlockNum * heightBlockNum];
  Arrays.fill(prevIdx, -1);
  Double[] graph = new Double[widthBlockNum * heightBlockNum];
  Arrays.fill(graph, (double)1000000000.0);
  graph[latLng2Int(parentRover.getPosition())] = (double)0;
  while (!qu.isEmpty()) {
    Pair<Double, LatLng> p = (Pair<Double, LatLng>)qu.poll();

    int h = floor((float)p.getValue().lat / oneBlockEdge), w = floor((float)p.getValue().lng / oneBlockEdge);
    // println(w, h);
    for (int i = -1; i < 2; i++) {
      for (int j = -1; j < 2; j++) {
        if ((i == 0 && j == 0) || w + i < 0 || w + i >= widthBlockNum || h + j < 0 || h + j >= heightBlockNum) {
          continue;
        }
        int idx = (w + i) * heightBlockNum + h + j;
        Double newCost = p.getKey() + cost[idx];
        if (newCost < graph[idx]) {
          graph[idx] = newCost;
          qu.add(new Pair<Double, LatLng>(newCost, new LatLng((h + j) * oneBlockEdge, (w + i) * oneBlockEdge)));
          prevIdx[idx] = w * heightBlockNum + h;
          // println("(" , w, ", ", h, ") -> (", w + i, ", ", h + j, "): ", newCost);
        }
      }
    }
  }
  println("-------------------------------------------------------");
  for (int i = 0; i < heightBlockNum; i++) {
    for (int j = 0; j < widthBlockNum; j++) {
      print(String.format("%4d", Math.round(graph[i + j * heightBlockNum])), ", ");
    }
    println();
  }
  println("-------------------------------------------------------");
  for (int i = 0; i < heightBlockNum; i++) {
    for (int j = 0; j < widthBlockNum; j++) {
      print(prevIdx[i + j * heightBlockNum], ", ");
    }
    println();
  }
  ArrayList<Pair<LatLng, Float>> stateHistory = new ArrayList<Pair<LatLng, Float>>();
  LatLng goalCoord = new LatLng((heightBlockNum - 1) / 2 * oneBlockEdge, (widthBlockNum - 1) * oneBlockEdge);
  stateHistory.add(new Pair<LatLng, Float>(goalCoord, (float)0));
  int idx = latLng2Int(stateHistory.get(stateHistory.size() - 1).getKey());
  println(idx);
  while (prevIdx[idx] != -1) {
    idx = prevIdx[idx];
    println(idx);
    stateHistory.add(new Pair<LatLng, Float>(new LatLng((idx % heightBlockNum + 0.5) * oneBlockEdge, (int)(idx / heightBlockNum + 0.5) * oneBlockEdge), (float)0));
  }
  Collections.reverse(stateHistory);
  stateHistories.add(stateHistory);
}

ArrayList<SearchRecord> findBoundingRecord(final LatLng latLng, ArrayList<SearchRecord> records) {
  ArrayList<SearchRecord> filteredRecords = new ArrayList<SearchRecord>();
  for (SearchRecord record : records) {
    double latDiff = record.lat - latLng.lat;
    double lngDiff = record.lng - latLng.lng;
    if ((latDiff * latDiff + lngDiff * lngDiff) < 25 * PIXEL_PER_METER * PIXEL_PER_METER) {
      filteredRecords.add(record);
    }
  }
  return filteredRecords;
}

ArrayList<Pair<LatLng, LatLng>> getCollidedOtherRoverTargetPath(LatLng coord, LatLng target, ArrayList<Pair<LatLng, LatLng>> positionsSet) { 
  // 仮目標地点から自機までの角度
  float rad = atan2((float)(coord.lat - target.lat), (float)(coord.lng - target.lng));
  double diffX = cos(rad) * PIXEL_PER_METER * 5 * 2;
  double diffY = sin(rad) * PIXEL_PER_METER * 5 * 2;
  
  ArrayList<Pair<LatLng, LatLng>> collidedPair = new ArrayList<Pair<LatLng, LatLng>>();
  for (Pair<LatLng, LatLng> pair : positionsSet) {
    LatLng coordL = new LatLng(coord.lat + diffY - diffX, coord.lng + diffX + diffY);
    LatLng coordR = new LatLng(coord.lat + diffY + diffX, coord.lng + diffX - diffY);
    LatLng targetL = new LatLng(target.lat - diffY - diffX, target.lng - diffX + diffY);
    LatLng targetR = new LatLng(target.lat - diffY + diffX, target.lng - diffX - diffY);
    
    // DEBUG
    //stroke(255, 255, 0);
    //line((float)pair.getKey().lng, (float)pair.getKey().lat, (float)pair.getValue().lng, (float)pair.getValue().lat);
      
    if (pair.getValue() != null) { //targtargetCoordetPositionはnullの可能性がある
      // 線分交差判定(線がぶつかっていたらやめる), 長方形内外点判定(点が内側にあったらやめる)
      if (crossLineJudge(coordR, targetR, pair.getKey(), pair.getValue()) // 線分交差判定 右側
      || crossLineJudge(coordL, targetL, pair.getKey(), pair.getValue()) //線分交差判定 左側
      || pointInCheck(coordR, targetR, targetL, coordL, pair.getKey()) // 長方形内外点判定 他子機自点
      || pointInCheck(coordR, targetR, targetL, coordL, pair.getValue())) { // 長方形内外点判定 他子機目標点 
        collidedPair.add(pair);
        break;
      }
    } else {
      // 長方形内外点判定(点が内側にあったらやめる)
      if (pointInCheck(coordR, targetR, targetL, coordL, pair.getKey())) {
        collidedPair.add(pair);
        break;
      }
    }
  }

  return collidedPair;
}

/*
* Utility =======================
 */
class LatLng {
  double lat; //y
  double lng; //x

  LatLng(double lat, double lng) {
    this.lat = lat;
    this.lng = lng;
  }
}

// 平均
float mean(ArrayList<Double> x) {
  float sum = 0;
  for (int i = 0; i < x.size(); i++) {
    sum += x.get(i);
  }
  return sum / x.size();
}

// 分散
float variance(ArrayList<Double> x) {
  float mean = mean(x);
  float sum = 0;
  for (int i = 0; i < x.size(); i++) {
    float diff = x.get(i).floatValue() - mean;
    sum += diff * diff;
  }
  return sum / x.size();
}

// 標準偏差
float standardDeviation(ArrayList<Double> x) {
  return sqrt(variance(x));
}

double bivariateNormalDistribution(double x, double y, Double[] mu, Double[] sigma) {
  return Math.exp(-(Math.pow(x - mu[0], 2) / Math.pow(sigma[0], 2) + Math.pow(y - mu[1], 2) / Math.pow(sigma[1], 2))/(2 * Math.pow(sigma[0], 2) * Math.pow(sigma[1], 2))) / (2 * Math.PI * sigma[0] * sigma[1]);
}

// 線分交差
// 線分a1a2, b1b2が交差する場合True
// 端点が他方の線分上にある場合もTrue
// 端点が他方の線分の延長線上にある場合もTrueを返すので注意
boolean crossLineJudge(LatLng a1, LatLng a2, LatLng b1, LatLng b2) {
    double s, t;
    s = (a1.lng - a2.lng) * (b1.lat - a1.lat) - (a1.lat - a2.lat) * (b1.lng - a1.lng);
    t = (a1.lng - a2.lng) * (b2.lat - a1.lat) - (a1.lat - a2.lat) * (b2.lng - a1.lng);
    if (s * t > 0) return false;

    s = (b1.lng - b2.lng) * (a1.lat - b1.lat) - (b1.lat - b2.lat) * (a1.lng - b1.lng);
    t = (b1.lng - b2.lng) * (a2.lat - b1.lat) - (b1.lat - b2.lat) * (a2.lng - b1.lng);
    if (s * t > 0) return false;
    return true;
}

double pointDistance(LatLng p1, LatLng p2) {
  double latDiff = p1.lat - p2.lat;
  double lngDiff = p1.lng - p2.lng;
  return sqrt((float)(latDiff * latDiff + lngDiff * lngDiff));
}

// 線分(l1, l2)・点(p)の距離を返す
double linePointMinDistance(LatLng l1, LatLng l2, LatLng p) {
  double a = p.lng - l2.lng;
  double b = p.lat - l2.lat;
  double a2 = a * a;
  double b2 = b * b;
  double r2 = a2 + b2;
  double tt = -(a * (l2.lng - l1.lng)+ b * (l2.lat - l1.lat));
  if( tt < 0 ) {
    return (l2.lng - l1.lng)*(l2.lng - l1.lng) + (l2.lat - l1.lat)*(l2.lat - l1.lat);
  }
  if( tt > r2 ) {
    return (p.lng - l1.lng) * (p.lng - l1.lng) + (p.lat - l1.lat) * (p.lat - l1.lat);
  }
  double f1 = a * (l2.lat - l1.lat) - b * (l2.lng - l1.lng);
  return (f1 * f1) / r2;
}

// 点が長方形の内側にある
// 参考: https://yttm-work.jp/collision/collision_0007.html#head_line_02
boolean pointInCheck(LatLng a1, LatLng a2, LatLng a3, LatLng a4, LatLng p){
  LatLng[] a = {a1, a2, a3, a4};
  for (int i = 0; i < 4; i++) {
    double edgeDiffX = a[(i + 1) % 4].lng - a[i].lng;
    double edgeDiffY = a[(i + 1) % 4].lat - a[i].lat;
    double pointDiffX = p.lng - a[i].lng;
    double pointDiffY = p.lat - a[i].lat;
    if (crossProduct(edgeDiffX, edgeDiffY, pointDiffX, pointDiffY) < 0) {
      return false;
    }
  }
  return true;
}

boolean isExistPointRight(LatLng a1, LatLng a2, LatLng p) {
  double ax = a2.lng - a1.lng;
  double ay = a2.lat - a1.lat;
  double bx = a2.lng - p.lng;
  double by = a2.lat - p.lat;
  return crossProduct(ax, ay, bx, by) >= 0;
}

double crossProduct(double ax, double ay, double bx, double by){
     return ax * by - bx * ay;
}
