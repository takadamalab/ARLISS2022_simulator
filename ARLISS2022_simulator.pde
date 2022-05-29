/*
* Processing描画関数 =======================
*/

long lastMillisTime;
final int SCREEN_WIDTH = 960;
final int SCREEN_HEIGHT = 360;
final int pixelPerMeter = 10; // ピクセル数/m

final String mapImageFileName = "map.jpg";
PImage mapImage;
boolean isShowMap = true;
boolean isShowGrid = true;

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
  parentRover = new ParentRover(SCREEN_HEIGHT / 2, 10, 90);
  childrenRovers = new ArrayList<ChildRover>();
  for (int i = 0; i < CHILDREN_ROVERS_NUM; i++) {
     childrenRovers.add(new ChildRover(SCREEN_HEIGHT / 2 + (i - CHILDREN_ROVERS_NUM / 2) * pixelPerMeter * 5, 30, 90));
  }
  
}

final String COMMAND_TEXT = "[コマンド]\n" 
  + "　地形表示切り替え: m\n"
  + "　グリッド切り替え: g";
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
    for (int i = 1; i < (int)(SCREEN_WIDTH / (5 * pixelPerMeter)); i++) {
      line(i * 5 * pixelPerMeter, 0, i * 5 * pixelPerMeter, SCREEN_HEIGHT);
    }
    for (int i = 1; i < (int)(SCREEN_HEIGHT / (5 * pixelPerMeter)); i++) {
      line(0, i * 5 * pixelPerMeter, SCREEN_WIDTH, i * 5 * pixelPerMeter);
    }
    noStroke();
  }
  
  // テキスト表示
  
  // ローバー更新
  parentRover.update(deltaT);
  //DEBUG
  for (ChildRover chileRover : childrenRovers) {
     chileRover.velocity = 3 * pixelPerMeter;
     chileRover.targetAzimuth = 0;
     chileRover.update(deltaT);
  }
  
  // ローバー描画
  drawRover(parentRover, 100, 0, 0);
  for (ChildRover chilerenRover : childrenRovers) {
     drawRover(chilerenRover, 0, 100, 0);
  }
  
  lastMillisTime = currentMillisTime;
}

void drawRover(RoverBase rover, int r, int g, int b) {
  fill(r, g, b);
  pushMatrix();
  LatLng latLng = rover.getCoord();
  translate((float)latLng.lng, (float)latLng.lat);
  rotate(radians((float)rover.getAzimuth()));
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
  }
}

/*
* シミュ用個体 =======================
*/

class RoverBase {
  // ローバプログラム関連
  private LatLng latLng; //y
  public double targetAzimuth;
  public double velocity; //速度 (加速度とかはめんどいので省略)
  private double azimuth;
  
  // シミュレーション上関連
  private final double rotateAbility = 10; // 回転速度deg/sec
  
  RoverBase(double lat, double lng, double azimuth) {
    this.latLng = new LatLng(lat, lng);
    this.velocity = 0;
    this.azimuth = azimuth;
    this.targetAzimuth = azimuth;
  }
  
  LatLng getCoord() {
    return latLng;
  }
  
  double getAzimuth() {
    return azimuth;
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
    latLng.lat += -cos(radians((float)azimuth)) * velocity * deltaT;
    latLng.lng += sin(radians((float)azimuth)) * velocity * deltaT;
    
    if (latLng.lat < 0) {
      latLng.lat = 0;
    } else if (latLng.lat > SCREEN_HEIGHT) {
      latLng.lat = SCREEN_HEIGHT;
    }
    
    if (latLng.lng < 0) {
      latLng.lng = 0;
    } else if (latLng.lng > SCREEN_WIDTH) {
      latLng.lng = SCREEN_WIDTH;
    }
  }
}

class ParentRover extends RoverBase {
  ParentRover(double lat, double lng, double azimuth) {
    super(lat, lng, azimuth);
  }
}

class ChildRover extends RoverBase {
  ChildRover(double lat, double lng, double azimuth) {
    super(lat, lng, azimuth);
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
