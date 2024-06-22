PVector target; // 目標地点
ArrayList<Obstacle> obstacles; // 障害物のリスト

int initialZombie = 1;
int initialSurviver = 100;
float[] zombieSpeeds = {2}; // ゾンビの速度リスト
float topSpeed=7;
float topForce=0.06;
int seekRange=3000;

// 追加したフィールド
ArrayList<Boid> infectedBoids = new ArrayList<Boid>(); // 感染したボイドのリスト
int infectionCooldown = 120; // 感染後の停止時間(フレーム数

// グローバル変数として間隔パラメータを追加
float obstacleSpacing = 200.0; // 障害物間の最低間隔

// フレームカウンターを追加
int frameCounter = 0;

int rogisticInterval=5;


class Boid {
  PVector position;
  PVector velocity;
  PVector acceleration;
  float r;
  float maxforce; // 最大の操舵力
  float maxspeed; // 最大速度
  boolean isZombie; // ゾンビかどうか
  float desiredSeparation = 40.0f; // 障害物からの理想的な距離
  float rogisticParm=3.9f;
  Boolean isHalt=false;
  int cooldownTime = infectionCooldown; // 感染後の停止時間(フレーム数


  // 初期設定用のパラメータ
  float initialMaxForce = topForce;

  Boid(float x, float y, boolean isZombie, float speed) {
    acceleration = new PVector(0, 0);
    float angle = random(TWO_PI);
    velocity = new PVector(cos(angle), sin(angle));
    position = new PVector(x, y);
    r = 10.0;
    this.isZombie = isZombie;

    if (isZombie) {
      maxspeed = speed;
      maxforce = speed * initialMaxForce;
    } else {
      maxspeed = speed;
      maxforce = initialMaxForce;
    }
  }
  // Boidクラス内のrunメソッドを修正（変更部分のみ）
  void run(ArrayList<Boid> boids) {
    // 感染したボイドの停止処理
    if (infectedBoids.contains(this)) {
      isHalt=true;
      cooldownTime--;
      if (cooldownTime <= 0) {
        infectedBoids.remove(this);
        cooldownTime=infectionCooldown; // 感染クールダウンをリセット
        isHalt=false;
      } 
    }
  
    if (!isHalt){
      // 通常の処理
      if (isZombie) {
        chaseSurvivors(boids); // ゾンビがサバイバーを追いかける
      } else {
        avoidZombies(boids); // サバイバーがゾンビを避ける
        flock(boids); // サバイバー同士で群れのルールに従う
      }
      avoidObstacles(obstacles); // 障害物を避ける力を適用
      update(); // ボイドの状態を更新
      borders(); // 画面端での処理を行う
    }
    render(); // ボイドを描画
  }

  void applyForce(PVector force) {
    acceleration.add(force);
  }

  void flock(ArrayList<Boid> boids) {
    PVector sep = separate(boids);   // 分離
    PVector ali = align(boids);      // 整列
    PVector coh = cohesion(boids);   // 結束
    sep.mult(1.5f);
    ali.mult(1.0f);
    coh.mult(1.0f);
    applyForce(sep);
    applyForce(ali);
    applyForce(coh);
  }

  void update() {
    velocity.add(acceleration);
    velocity.limit(maxspeed);
    position.add(velocity);
    acceleration.mult(0);
  }

  PVector seek(PVector target) {
    PVector desired = PVector.sub(target, position);
    desired.normalize();
    desired.mult(maxspeed);
    
    // 10フレームごとにロジスティック写像を適用
    if (frameCounter % rogisticInterval == 0) {
      if(isZombie){
        float x=maxspeed/topSpeed;
        float rogistic=topSpeed*(rogisticParm * x*(1-x)); //ロジスティク写像
        maxspeed=rogistic;
      }
    }

    PVector steer = PVector.sub(desired, velocity);
    steer.limit(maxforce);
    return steer;
  }

  void avoidObstacles(ArrayList<Obstacle> obstacles) {
    for (Obstacle obstacle : obstacles) {
      PVector steer = new PVector(0, 0);
      PVector diff = PVector.sub(position, obstacle.position);
      float d = dist(position.x, position.y, obstacle.position.x, obstacle.position.y);
      if (d < desiredSeparation + max(obstacle.width, obstacle.height) / 2) {
        diff.normalize();
        diff.div(d); // 障害物に近いほど強く反発
        steer.add(diff);
      }
      steer.normalize();
      steer.mult(maxspeed);
      steer.limit(maxforce * 3);
      applyForce(steer);
    }
  }

  void render() {
    fill(isZombie ? color(0, 255, 0) : color(0, 0, 255), 100); // ゾンビは赤、サバイバーは青で描画
    stroke(255); // 白い枠線を設定
    pushMatrix(); // 現在の描画状態を保存
    translate(position.x, position.y); // ボイドの位置に移動
    // 三角形から円に変更
    ellipse(0, 0, r * 2, r * 2); // 半径rの円を描画 (r * 2は直径)
    popMatrix(); // 保存した描画状態を復元
  }

  void borders() {
    if (position.x < -r) position.x = width + r;
    if (position.y < -r) position.y = height + r;
    if (position.x > width + r) position.x = -r;
    if (position.y > height + r) position.y = -r;
  }

  PVector separate(ArrayList<Boid> boids) {
    float desiredseparation = 25.0f;
    PVector steer = new PVector(0, 0, 0);
    int count = 0;
    for (Boid other : boids) {
      if(!other.isZombie){
        float d = PVector.dist(position, other.position);
        if ((d > 0) && (d < desiredseparation)) {
          PVector diff = PVector.sub(position, other.position);
          diff.normalize();
          diff.div(d);
          steer.add(diff);
          count++;
        }
      }
    }
    if (count > 0) {
      steer.div((float)count);
    }
    if (steer.mag() > 0) {
      steer.normalize();
      steer.mult(maxspeed);
      steer.sub(velocity);
      steer.limit(maxforce);
    }
    return steer;
  }

  PVector align(ArrayList<Boid> boids) {
    float neighbordist = 50;
    PVector sum = new PVector(0, 0);
    int count = 0;
    for (Boid other : boids) {
      float d = PVector.dist(position, other.position);
       if(!other.isZombie){
          if ((d > 0) && (d < neighbordist)) {
            sum.add(other.velocity);
            count++;
          }
       }
    }
    if (count > 0) {
      sum.div((float)count);
      sum.normalize();
      sum.mult(maxspeed);
      PVector steer = PVector.sub(sum, velocity);
      steer.limit(maxforce);
      return steer;
    } else {
      return new PVector(0, 0);
    }
  }

  PVector cohesion(ArrayList<Boid> boids) {
    float neighbordist = 50;
    PVector sum = new PVector(0, 0);
    int count = 0;
    for (Boid other : boids) {
      float d = PVector.dist(position, other.position);
       if(!other.isZombie){
          if ((d > 0) && (d < neighbordist)) {
            sum.add(other.position);
            count++;
          }
       }
    }
    if (count > 0) {
      sum.div(count);
      return seek(sum);
    } else {
      return new PVector(0, 0);
    }
  }

  // chaseSurvivors()メソッドを修正
  void chaseSurvivors(ArrayList<Boid> boids) {
    
    //追いかけるサバイバーを探索
    Boid closestSurvivor = null;
    float minDist = seekRange;
    for (Boid other : boids) {
      if (!other.isZombie) {
        float d = PVector.dist(position, other.position);
        if (d < minDist) {
          minDist = d;
          closestSurvivor = other;
        }
      }
    }
    
     if (closestSurvivor != null) {
      PVector chaseForce = seek(closestSurvivor.position);
      applyForce(chaseForce);
      if (minDist < r*2) {
        closestSurvivor.isZombie = true; // サバイバーがゾンビに変わる

        float rogistic = closestSurvivor.maxspeed; //仮
        closestSurvivor.maxspeed = rogistic; // 新しいゾンビの速度を設定
        closestSurvivor.maxforce = rogistic * initialMaxForce; // 新しいゾンビの操舵力を設定
        
        // 感染したボイドをリストに追加
        infectedBoids.add(this);
        infectedBoids.add(closestSurvivor);
      }
    }
  }

  void avoidZombies(ArrayList<Boid> boids) {
    PVector avoidForce = new PVector(0, 0);
    int count = 0;
    for (Boid other : boids) {
      if (other.isZombie) {
        float d = PVector.dist(position, other.position);
        if (d < desiredSeparation * 2) {
          PVector diff = PVector.sub(position, other.position);
          diff.normalize();
          avoidForce.add(diff);
          count++;
        }
      }
    }
    if (count > 0) {
      avoidForce.div((float)count);
      avoidForce.normalize();
      avoidForce.mult(maxspeed);
      avoidForce.sub(velocity);
      avoidForce.limit(maxforce);
      applyForce(avoidForce);
    }
  }
}

class Obstacle {
  PVector position;
  float width;
  float height;

  Obstacle(PVector pos, float w, float h) {
    position = pos;
    width = w;
    height = h;
  }

  void display() {
    fill(0, 0, 0);
    noStroke();
    rectMode(CENTER);
    rect(position.x, position.y, width, height);
  }
}

class Flock {
  ArrayList<Boid> boids;

  Flock() {
    boids = new ArrayList<Boid>();
  }

  void run() {
    for (Boid b : boids) {
      b.run(boids);
    }
  }

  void addBoid(Boid b) {
    boids.add(b);
  }
}

Flock flock;

void setup() {
  size(1920, 1080);
  flock = new Flock();
  obstacles = new ArrayList<Obstacle>();
  target = new PVector(width / 2, height / 2);

  // 初期設定のゾンビの速度と力
  for (int i = 0; i < initialSurviver; i++) {
    flock.addBoid(new Boid(random(width), random(height), false, 1.5f)); // サバイバーを追加
  }
  for (int i = 0; i < initialZombie; i++) {
    float speed = zombieSpeeds[int(random(zombieSpeeds.length))];
    flock.addBoid(new Boid(random(width), random(height), true, speed)); // ゾンビを追加
  }

  // 障害物の生成と配置
  generateObstacles();
  
  //fullScreen();
}

void draw() {
  background(50);
  flock.run();
  drawObstacles();
  
  // フレームカウンターを更新
  frameCounter++;
}

void generateObstacles() {
  int numObstacles = 10;

  while (obstacles.size() < numObstacles) {
    PVector pos = new PVector(random(width), random(height));
    float w = random(50, 300);
    float h = random(50, 300);
    boolean valid = true;

    // 障害物が他の障害物やエージェントと重ならないようにする
    for (Obstacle o : obstacles) {
      if (PVector.dist(pos, o.position) < obstacleSpacing + max(o.width, o.height) / 2) {
        valid = false;
        break;
      }
    }

    if (valid) {
      obstacles.add(new Obstacle(pos, w, h));
    }
  }
}


void drawObstacles() {
  for (Obstacle obstacle : obstacles) {
    obstacle.display();
  }
}

void mousePressed() {
  flock.addBoid(new Boid(mouseX, mouseY, false, 2)); // クリックでサバイバーを追加
  target = new PVector(mouseX, mouseY);
}
