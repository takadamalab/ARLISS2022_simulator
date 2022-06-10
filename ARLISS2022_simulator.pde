import com.github.chen0040.rl.actionselection.*;
import com.github.chen0040.rl.learning.actorcritic.*;
import com.github.chen0040.rl.learning.qlearn.*;
import com.github.chen0040.rl.learning.rlearn.*;
import com.github.chen0040.rl.learning.sarsa.*;
import com.github.chen0040.rl.models.*;
import com.github.chen0040.rl.utils.*;

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

// setup()実行後に繰り返し実行される処理
void draw() {
  if (lastMillisTime == -1) {
    //　初回はテキストロードで時間がかかるので、それだけ先に処理させる
    text(COMMAND_TEXT, SCREEN_WIDTH - COMMAND_TEXT_WIDTH, 0, COMMAND_TEXT_WIDTH, SCREEN_HEIGHT);
    lastMillisTime = millis(); 
    return;
  }
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
      for (ChildRover childRover : childrenRovers) {
        switch(searchMode) { // 探索モードで行動変化
        case STRAIGHT:
          childRover.targetAzimuth = 90;
          childRover.velocity = 8 * PIXEL_PER_METER;
          break;
        case ZIGZAG:
          // TODO: ジグザクの実装
          childRover.targetCoord = new LatLng(SCREEN_HEIGHT / 2, goalLineLng);
          break;
        }
      }
      mode = Mode.CHILDREN_SERACH;
    }
  } else if (mode == Mode.CHILDREN_SERACH) {
    switch(searchMode) { // 探索モードで行動変化
    case STRAIGHT:
      for (ChildRover childRover : childrenRovers) {
        if (childRover.getCoord().lng > goalLineLng && !finishedSearchRoverIds.contains(childRover.id)) {
          finishedSearchRoverIds.add(childRover.id);
          childRover.velocity = 0;
        }
      }

      break;
    case ZIGZAG:
      for (ChildRover childRover : childrenRovers) {
        childRover.targetCoord = new LatLng(SCREEN_HEIGHT / 2, goalLineLng);
        if (childRover.isOnTargetPosition() && !finishedSearchRoverIds.contains(childRover.id)) {
          finishedSearchRoverIds.add(childRover.id);
          childRover.targetCoord = null;
          childRover.velocity = 0;
        }
      }
      break;
    }

    // 探索終了個体でモード変更
    if (finishedSearchRoverIds.size() == CHILDREN_ROVERS_NUM) {
      mode = Mode.SEND_CHILDREN_DATA;
    }
  } else if (mode == Mode.SEND_CHILDREN_DATA) {
    // 省略(実機では通信などでデータを送る必要がある)
    mode = Mode.CARRY_PARENT;
  } else if (mode == Mode.CARRY_PARENT) {
    if (currentMillisTime - lastTrainTime > 0 && trainCount < 10000) {
      System.out.println("train: " + trainCount + "/1000");
      // train();
      if ( trainCount == 0){
        dijkstra();
      }
      trainCount++;
      lastTrainTime = currentMillisTime;
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

enum SearchMode {
  STRAIGHT, // 直進
    ZIGZAG // ジグザグ
};
SearchMode searchMode = SearchMode.STRAIGHT;
HashSet<Integer> finishedSearchRoverIds = new HashSet<Integer>(); // 探索が終了したローバのid

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
  public double velocity; //速度 (加速度とかはめんどいので省略)
  private double azimuth;
  private double accelZ;

  // シミュレーション上関連
  private final double rotateAbility = 10; // 回転速度deg/sec
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
    return azimuth - 5.0 + random(10.0);
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
    return latDiff * latDiff + lngDiff * lngDiff < gpsError * gpsError * PIXEL_PER_METER * PIXEL_PER_METER;
  }

  void update(double deltaT) {
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

    if (latLng.lat < gpsError * PIXEL_PER_METER * 2) {
      latLng.lat = gpsError * PIXEL_PER_METER * 2;
    } else if (latLng.lat > SCREEN_HEIGHT - gpsError * PIXEL_PER_METER * 2) {
      latLng.lat = SCREEN_HEIGHT - gpsError * PIXEL_PER_METER * 2;
    }

    if (latLng.lng < gpsError * PIXEL_PER_METER * 2) {
      latLng.lng = gpsError * PIXEL_PER_METER * 2;
    } else if (latLng.lng > SCREEN_WIDTH - gpsError * PIXEL_PER_METER * 2) {
      latLng.lng = SCREEN_WIDTH - gpsError * PIXEL_PER_METER * 2;
    }

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

  ChildRover(int id, double lat, double lng, double azimuth) {
    super(id, lat, lng, azimuth);
  }

  @Override void update(double deltaT) {
    // 調査記録
    if (mode == Mode.CHILDREN_SERACH) {
      lastRecordElipsedTime += deltaT;
      if (lastRecordElipsedTime > 0.5) {
        LatLng coord = getCoord();
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
* 強化学習 =======================
 */

class World {
  private ArrayList<SearchRecord> records = null;
  public int update(ActorCriticLearner agent, Action action, int stateId) {
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

  public double reward(ActorCriticLearner agent, int stateId, Action action) {
    LatLng latLng = stateToLatLng(stateId);
    ArrayList<SearchRecord> boundingRecords = findBoundingRecord(latLng, records);

    double reward = 0;
    // ゴール！
    //if ((stateId / Action.SIZE.ordinal()) % widthBlockNum == widthBlockNum - 1) {
    //  reward += 1000;
    //}

    if (boundingRecords.isEmpty()) {
      return floor((float)stateId / Action.SIZE.ordinal()) % widthBlockNum <= 4 ? 0 : -0.2;
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

    // System.out.println("weightAve: " + weightAve + ", finalReward:" + (10 / (weightAve * weightAve) - 0.2));

    reward += 10 / (weightAve * weightAve);

    return reward;
  }

  public Set<Integer> getActionsAvailableAtState(int newState, Action oldAction) {
    HashSet<Action> actionSet;
    //if (oldAction == null) {
    //  // 全アクション生成
    //  actionSet = new HashSet<Action>(Arrays.asList(Action.values()));
    //  actionSet.remove(Action.SIZE);
    //} else {
    //  // 前回のActionから近いアクションを生成する
    //  int actionSize = Action.SIZE.ordinal();
    //  actionSet = new HashSet<Action>();
    //  actionSet.add(Action.fromInteger((oldAction.ordinal() + actionSize - 1) % actionSize)); //一つ左回り
    //  actionSet.add(oldAction); // 同方向
    //  actionSet.add(Action.fromInteger((oldAction.ordinal() + actionSize + 1) % actionSize)); //一つ右回り
    //}

    //Action action = Action.fromInteger(newState % Action.SIZE.ordinal());
    int lngNo = (int)floor((float)newState / Action.SIZE.ordinal()) % widthBlockNum;
    int latNo = floor((float)newState / (Action.SIZE.ordinal() * widthBlockNum));

    actionSet = new HashSet<Action>();

    if (oldAction != Action.UP) {
      actionSet.add(Action.BOTTOM);
    }
    if (oldAction != Action.BOTTOM) {
      actionSet.add(Action.UP);
    }
    actionSet.add(Action.UPPER_RIGHT);
    actionSet.add(Action.RIGHT);
    actionSet.add(Action.BOTTOM_RIGHT);

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
          return new Double(-0.2);
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
ActorCriticLearner agent = new ActorCriticLearner(stateCount, actionCount);

void train() {
  ArrayList<Pair<LatLng, Float>> stateHistory = new ArrayList<Pair<LatLng, Float>>();

  ArrayList<SearchRecord> records = new ArrayList();
  for (ChildRover rover : childrenRovers) {
    records.addAll(rover.getRecords());
  }

  World world = new World();
  world.setSearchRecords(records);
  Function<Integer, Double> V = world.getValueFunction();

  int currentState = world.getState(parentRover, Action.RIGHT);
  List<Move> moves = new ArrayList<Move>();
  Action oldAction = Action.RIGHT;

  for (int time=0; time < 10000; ++time) {
    Action action = Action.fromInteger(agent.selectAction(currentState, world.getActionsAvailableAtState(currentState, oldAction)));
    // System.out.println("Agent does action-"+action);

    int newStateId = world.update(agent, action, currentState);
    double reward = world.reward(agent, currentState, action);
    int oldStateId = currentState;
    moves.add(new Move(oldStateId, action, newStateId, reward));
    currentState = newStateId;
    if (world.isGoal(currentState)) {
      //ゴールしたらbreak
      break;
    }
    oldAction = action;
  }

  String s = "";
  double allReward = 0;
  for (int i=moves.size()-1; i >= 0; --i) {
    Move next_move = moves.get(i);
    if (i != moves.size()-1) {
      next_move = moves.get(i+1);
    }
    Move current_move = moves.get(i);
    s = (int)(current_move.reward * 100) + ", " + s;
    allReward += current_move.reward;
    agent.update(current_move.oldState, current_move.action.ordinal(), current_move.newState, world.getActionsAvailableAtState(current_move.newState, current_move.action), current_move.reward, V);
    stateHistory.add(new Pair<LatLng, Float>(world.stateToLatLng(current_move.oldState), world.actionToDegree(current_move.action)));
  }
  System.out.println("allReward: " + allReward + ", reward: " + s);

  stateHistories.add(stateHistory);
}

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
          if(0 <= w + i && w + i < widthBlockNum && 0 <= h + j && h + j < heightBlockNum){
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
      if (weightSum[i * heightBlockNum + j] != 0.0){
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

void test() {
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
