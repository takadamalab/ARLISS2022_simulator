import java.util.Date;
import java.util.HashSet;

/*
* Processing描画関数 =======================
*/

long lastMillisTime;
final int SCREEN_WIDTH = 960;
final int SCREEN_HEIGHT = 360;
final int PIXEL_PER_METER = 10; // ピクセル数/m

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
  
  // ローバ初期化
  parentRover = new ParentRover(0, SCREEN_HEIGHT / 2, 10, 90);
  childrenRovers = new ArrayList<ChildRover>();
  for (int i = 0; i < CHILDREN_ROVERS_NUM; i++) {
     childrenRovers.add(new ChildRover(i + 1, SCREEN_HEIGHT / 2 + (i - CHILDREN_ROVERS_NUM / 2) * PIXEL_PER_METER * 5, 30, 90));
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
    for (int i = 1; i < (int)(SCREEN_WIDTH / (5 * PIXEL_PER_METER)); i++) {
      line(i * 5 * PIXEL_PER_METER, 0, i * 5 * PIXEL_PER_METER, SCREEN_HEIGHT);
    }
    for (int i = 1; i < (int)(SCREEN_HEIGHT / (5 * PIXEL_PER_METER)); i++) {
      line(0, i * 5 * PIXEL_PER_METER, SCREEN_WIDTH, i * 5 * PIXEL_PER_METER);
    }
    noStroke();
  }
  
  // ミッション系実行
  if (mode == Mode.STAY_PARENT_AND_CHILDREN) {
    // 初期位置は設定済みなのでそのまま探索開始
    mode = Mode.CHILDREN_SERACH;
  } else if (mode == Mode.CHILDREN_SERACH) {
    switch(searchMode) { // 探索モードで行動変化
      case STRAIGHT:
        for (ChildRover childRover : childrenRovers) {
           childRover.velocity = 3 * PIXEL_PER_METER;
           childRover.targetAzimuth = 90;
           if (childRover.getCoord().lng > SCREEN_WIDTH - 5 * PIXEL_PER_METER && !finishedSearchRoverIds.contains(childRover.id)) {
             finishedSearchRoverIds.add(childRover.id);
           }
        }
        
        break;
      case ZIGZAG:
        break;
    }
    
    // 探索終了個体でモード変更
    if (finishedSearchRoverIds.size() == CHILDREN_ROVERS_NUM) {
      mode = Mode.SEND_CHILDREN_DATA;
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
     stroke(0, 50 + 20 * i, 0, 100);
     noFill();
     ArrayList<SearchRecord> records = childRover.getRecords();
     for (SearchRecord record: records) {
       float gpsError = (float)childRover.getGpsError();
       strokeWeight(sqrt((float)record.accelZVariance * 100));
       circle((float)record.lng, (float)record.lat, gpsError * PIXEL_PER_METER * 2);
       line((float)record.lng, (float)record.lat, (float)record.lng + sin(radians((float)record.azimuth)) * gpsError * PIXEL_PER_METER, (float)record.lat + cos(radians((float)record.azimuth)) * gpsError * PIXEL_PER_METER);
     }
     noStroke();
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
    return new LatLng(latLng.lat - pixelError + random(2 * pixelError) * random(1.0), latLng.lng - pixelError + random(2 * pixelError) * random(1.0));
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
  
  void update(double deltaT) {
    // 回転制御
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
    
    if (latLng.lat < 10) {
      latLng.lat = 10;
    } else if (latLng.lat > SCREEN_HEIGHT - 10) {
      latLng.lat = SCREEN_HEIGHT - 10;
    }
    
    if (latLng.lng < 10) {
      latLng.lng = 10;
    } else if (latLng.lng > SCREEN_WIDTH - 10) {
      latLng.lng = SCREEN_WIDTH - 10;
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
      if (lastRecordElipsedTime > 1.0) {
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
