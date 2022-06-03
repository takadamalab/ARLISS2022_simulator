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

long lastMillisTime;
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
  lastMillisTime = millis();
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
    for (ChildRover childRover : childrenRovers) {
       childRover.velocity = 8 * PIXEL_PER_METER;
       switch(searchMode) { // 探索モードで行動変化
          case STRAIGHT:
            childRover.targetAzimuth = 90;
            break;
          case ZIGZAG:
            // TODO: ジグザクの実装
            childRover.targetCoord = new LatLng(SCREEN_HEIGHT / 2, goalLineLng);
            break;
        }
    }
    mode = Mode.CHILDREN_SERACH;
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
    System.out.println("train: " + trainCount + "/1000");
    if (trainCount < 1000) {
      train();
      trainCount++;
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
     for (SearchRecord record: records) {
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

enum Mode{ // 全体のモード
    STAY_PARENT_AND_CHILDREN, //親機子機待機
    CHILDREN_SERACH, // 子機探索
    SEND_CHILDREN_DATA, // 探索データの送信
    CARRY_PARENT, // 親機学習&移動
    CALL_CHILDREN_AFTER_CARRY,
};
Mode mode = Mode.STAY_PARENT_AND_CHILDREN;

enum SearchMode{
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
      public int update(ActorCriticLearner agent, Action action, int stateId) {
    //public Pair<Integer, Action> update(ActorCriticLearner agent, Action action, int stateId) {
      // 壁対策(回避は右回りで統一)
      //if (stateId % widthBlockNum == 0 && (action == Action.UPPER_LEFT || action == Action.LEFT || action == Action.BOTTOM_LEFT)){ //左端
      //  return update(agent, Action.UP, stateId);
      //}
      //if ((int)(stateId / widthBlockNum) == heightBlockNum - 1 && (action == Action.UPPER_LEFT || action == Action.UP || action == Action.UPPER_RIGHT)){ //上端
      //  return update(agent, Action.RIGHT, stateId);
      //}
      //if (stateId % widthBlockNum == widthBlockNum - 1 && (action == Action.UPPER_RIGHT || action == Action.RIGHT || action == Action.BOTTOM_RIGHT)){ //右端
      //  return update(agent, Action.BOTTOM, stateId);
      //}
      //if ((int)(stateId / widthBlockNum) == 0 && (action == Action.BOTTOM_LEFT || action == Action.BOTTOM || action == Action.BOTTOM_RIGHT)){ //下端
      //  return update(agent, Action.LEFT, stateId);
      //}
      
      switch(action) {
        case UP:
        stateId += widthBlockNum;
        break;
        case UPPER_RIGHT:
        stateId += widthBlockNum + 1;
        break;
        case RIGHT:
        stateId += 1;
        break;
        case BOTTOM_RIGHT:
        stateId += -widthBlockNum + 1;
        break;
        case BOTTOM:
        stateId += -widthBlockNum;
        break;
        case BOTTOM_LEFT:
        stateId += -widthBlockNum - 1;
        break;
        case LEFT:
        stateId += -1;
        break;
        case UPPER_LEFT:
        stateId += widthBlockNum - 1;
        break;
        default:
        break;
      }
      
      return stateId;
    }
    
    public double reward(ActorCriticLearner agent, int stateId, Action action, ArrayList<SearchRecord> records) {
      LatLng latLng = stateToLatLng(stateId);
      ArrayList<SearchRecord> boundingRecords = findBoundingRecord(latLng, records);
   
      int reward = 0;
      // ゴール！
      if (stateId % widthBlockNum == widthBlockNum - 1) {
        reward += 1000;
      }
      
      if (boundingRecords.isEmpty()) {
        return -1;
      }
      
      double weightSum = 0;
      double accelZVarianceWeightSum = 0;
      double currentAzimuth = actionToDegree(action);
      for (SearchRecord record: boundingRecords) {
        double azimuthDiff = record.azimuth - currentAzimuth;
        while(azimuthDiff < -180) {
          azimuthDiff += 360;
        }
        while(azimuthDiff > 180) {
          azimuthDiff -= 360;
        }
        float weight = 180 - abs((float)azimuthDiff);
        accelZVarianceWeightSum += record.accelZVariance * weight;
        weightSum += weight;
      }
      
      reward += 10 / weightSum * accelZVarianceWeightSum;
      
      return reward;
    }
    
    public Set<Integer> getActionsAvailableAtState(int newState) {
      HashSet<Action> actionSet = new HashSet<Action>(Arrays.asList(Action.values()));
      actionSet.remove(Action.SIZE);
      
      if (newState % widthBlockNum == 0){ //左端
        actionSet.remove(Action.UPPER_LEFT);
        actionSet.remove(Action.LEFT);
        actionSet.remove(Action.BOTTOM_LEFT);
      }
      if (floor((float)newState / widthBlockNum) == heightBlockNum - 1){ //上端
        actionSet.remove(Action.UPPER_LEFT);
        actionSet.remove(Action.UP);
        actionSet.remove(Action.UPPER_RIGHT);
      }
      if (newState % widthBlockNum == widthBlockNum - 1){ //右端
        actionSet.remove(Action.UPPER_RIGHT);
        actionSet.remove(Action.RIGHT);
        actionSet.remove(Action.BOTTOM_RIGHT);
      }
      if (floor((float)newState / widthBlockNum) == 0){ //下端
        actionSet.remove(Action.BOTTOM_LEFT);
        actionSet.remove(Action.BOTTOM);
        actionSet.remove(Action.BOTTOM_RIGHT);
      }
      
      HashSet<Integer> integerSet = new HashSet<Integer>();
      for (Action action: actionSet) {
        integerSet.add(action.ordinal());
      }
      
      return integerSet;
    }
    
    public int getState(RoverBase rover) {
      LatLng latLng = rover.getCoord();
      int stateId = floor((float)latLng.lng / oneBlockEdge) + floor((float)latLng.lat / oneBlockEdge) * widthBlockNum;     
      return stateId;
    }
    
    public LatLng stateToLatLng(int stateId) {
      double lng = (stateId % widthBlockNum) * oneBlockEdge + (oneBlockEdge / 2);
      double lat = floor((float)stateId / widthBlockNum) * oneBlockEdge + (oneBlockEdge / 2);
      return new LatLng(lat, lng);
    }
    
    public float actionToDegree(Action action) {
      return 45.0 * action.ordinal();
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

ArrayList<ArrayList<Pair<LatLng, Float>>> stateHistories = new ArrayList<ArrayList<Pair<LatLng, Float>>>();

int stateCount = widthBlockNum * heightBlockNum; // マップを7m正方形で分割したのがstateの数。7mなのはGPS半径5mの誤差円の内接正方形の一辺。
int actionCount = Action.SIZE.ordinal(); // 0: 上 1: 右上 で8方向
ActorCriticLearner agent = new ActorCriticLearner(stateCount, actionCount);

void train() {
  ArrayList<Pair<LatLng, Float>> stateHistory = new ArrayList<Pair<LatLng, Float>>();
  
  ArrayList<SearchRecord> records = new ArrayList();
  for (ChildRover rover: childrenRovers) {
    records.addAll(rover.getRecords());
  }
  
  World world = new World();
  Function<Integer, Double> V = new  Function<Integer, Double>() { // 参考: https://github.com/chen0040/java-reinforcement-learning/blob/f85cb03e5d16512f6bb9e126fa940b9e49d5bde7/src/main/java/com/github/chen0040/rl/learning/actorcritic/ActorCriticLearner.java#L85
    @Override
    public Double apply(Integer value) {
      return new Double(0); // TODO
    }
  };
  
  int currentState = world.getState(parentRover);
  List<Move> moves = new ArrayList<Move>();
  
  for(int time=0; time < 10000; ++time){
   Action action = Action.fromInteger(agent.selectAction(currentState, world.getActionsAvailableAtState(currentState)));
   //System.out.println("Agent does action-"+action);
   
   int newStateId = world.update(agent, action, currentState);
   double reward = world.reward(agent, currentState, action, records);
   int oldStateId = currentState;
   moves.add(new Move(oldStateId, action, newStateId, reward));
    currentState = newStateId;
    if (currentState % widthBlockNum == widthBlockNum - 1) {
      //ゴールしたらbreak
      System.out.println("time: " + time);
      break;
    }
  }
  
  for(int i=moves.size()-1; i >= 0; --i){
      Move next_move = moves.get(i);
      if(i != moves.size()-1) {
          next_move = moves.get(i+1);
      }
      Move current_move = moves.get(i);
      agent.update(current_move.oldState, current_move.action.ordinal(), current_move.newState, world.getActionsAvailableAtState(current_move.newState), current_move.reward, V);
      stateHistory.add(new Pair<LatLng, Float>(world.stateToLatLng(current_move.oldState), world.actionToDegree(current_move.action)));
  }
  
  stateHistories.add(stateHistory);
}

void test() {

}

ArrayList<SearchRecord> findBoundingRecord(final LatLng latLng, ArrayList<SearchRecord> records) {
  ArrayList<SearchRecord> filteredRecords = new ArrayList<SearchRecord>();
  for (SearchRecord record: records) {
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
