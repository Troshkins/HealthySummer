package main

import (
	"github.com/gin-gonic/gin"
	"net/http"
	"strconv"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"time"
	"sync"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"log"
	"os"
	"github.com/joho/godotenv"
	"github.com/gin-contrib/cors"
)

type User struct {
	ID     int     `json:"id" gorm:"primaryKey;autoIncrement"`
	Name   string  `json:"name" gorm:"not null"`
	Email  string  `json:"email" gorm:"unique;not null"`
	Password string `json:"-" gorm:"not null"`
	Weight float64 `json:"weight" gorm:"default:70"`
	Age    int     `json:"age" gorm:"default:18"`
	Sex    string  `json:"sex" gorm:"default:'other'"`
	Height float64 `json:"height" gorm:"default:170"`
}

type Workout struct {
	ID        int       `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID    int       `json:"user_id" gorm:"index;not null"`
	Type      string    `json:"type" gorm:"not null"`
	Duration  int       `json:"duration"`
	Intensity string    `json:"intensity"`
	Calories  int       `json:"calories"`
	Location  string    `json:"location"`
	CreatedAt time.Time `json:"created_at" gorm:"autoCreateTime"`
	Category  string    `json:"category"`
}

type WaterIntake struct {
	ID     int `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID int `json:"user_id" gorm:"index;not null"`
	Amount int `json:"amount"`
}

type DietEntry struct {
	ID       int    `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID   int    `json:"user_id" gorm:"index;not null"`
	Meal     string `json:"meal"`
	Food     string `json:"food"`
	Calories int    `json:"calories"`
}

type Period struct {
	ID     int    `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID int    `json:"user_id" gorm:"index;not null"`
	Start  string `json:"start"`
	End    string `json:"end"`
}

type Award struct {
	ID     int    `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID int    `json:"user_id" gorm:"index;not null"`
	Title  string `json:"title"`
	Desc   string `json:"desc"`
}

type Journey struct {
	ID      int    `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID  int    `json:"user_id" gorm:"index;not null"`
	Content string `json:"content"`
	Date    string `json:"date"`
}

type HealthRecord struct {
	ID     int    `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID int    `json:"user_id" gorm:"index;not null"`
	Type   string `json:"type"`
	Value  string `json:"value"`
	Date   string `json:"date"`
}

type Settings struct {
	UserID                int    `json:"user_id" gorm:"primaryKey"`
	NotificationsEnabled  bool   `json:"notificationsEnabled"`
	Theme                 string `json:"theme"`
	WaterGoal             int    `json:"water_goal" gorm:"default:2000"`
	CaloriesGoal          int    `json:"calories_goal" gorm:"default:2000"`
	StepsGoal             int    `json:"steps_goal" gorm:"default:10000"`
}

type Reminder struct {
	ID      int    `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID  int    `json:"user_id" gorm:"index;not null"`
	Time    string `json:"time"`
	Message string `json:"message"`
	Type    string `json:"type"`
}

type FriendRequest struct {
	ID         int       `json:"id" gorm:"primaryKey;autoIncrement"`
	FromUserID int       `json:"from_user_id" gorm:"index;not null"`
	ToUserID   int       `json:"to_user_id" gorm:"index;not null"`
	Status     string    `json:"status" gorm:"type:varchar(16);not null"` // pending, accepted, rejected
	CreatedAt  time.Time `json:"created_at" gorm:"autoCreateTime"`
}

type Friendship struct {
	ID        int       `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID1   int       `json:"user_id_1" gorm:"index;not null"`
	UserID2   int       `json:"user_id_2" gorm:"index;not null"`
	CreatedAt time.Time `json:"created_at" gorm:"autoCreateTime"`
}

type Activity struct {
	ID        int       `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID    int       `json:"user_id" gorm:"index;not null"`
	Type      string    `json:"type" gorm:"not null"` // workout, achievement, etc.
	Data      string    `json:"data" gorm:"type:jsonb"`
	CreatedAt time.Time `json:"created_at" gorm:"autoCreateTime"`
	IsPublic  bool      `json:"is_public" gorm:"default:true"`
}

type Message struct {
	ID          int       `json:"id" gorm:"primaryKey;autoIncrement"`
	SenderID    int       `json:"sender_id" gorm:"column:from_user_id;index;not null"`
	RecipientID int       `json:"recipient_id" gorm:"column:to_user_id;index;not null"`
	Content     string    `json:"content" gorm:"type:text;not null"`
	Timestamp   time.Time `json:"timestamp" gorm:"column:created_at;autoCreateTime"`
	Read        bool      `json:"read" gorm:"default:false"`
}

type Badge struct {
	ID        int       `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID    int       `json:"user_id" gorm:"index;not null"`
	Code      string    `json:"code" gorm:"not null"` // e.g., "steps_10k", "streak_7d", "workouts_5w"
	Title     string    `json:"title"`
	Desc      string    `json:"desc"`
	EarnedAt  time.Time `json:"earned_at" gorm:"autoCreateTime"`
}

type Streak struct {
	ID        int       `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID    int       `json:"user_id" gorm:"index;not null"`
	Type      string    `json:"type" gorm:"not null"` // "steps", "diet", "water"
	Current   int       `json:"current" gorm:"default:0"`
	Longest   int       `json:"longest" gorm:"default:0"`
	LastDate  string    `json:"last_date" gorm:"not null"` // YYYY-MM-DD format
	UpdatedAt time.Time `json:"updated_at" gorm:"autoUpdateTime"`
}

var triggeredReminders = struct {
	m map[int]bool
	sync.Mutex
}{m: make(map[int]bool)}

var db *gorm.DB

func initDB() {
	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")
	dbUser := os.Getenv("DB_USER")
	dbPassword := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")
	dsn := "host=" + dbHost + " user=" + dbUser + " password=" + dbPassword + " dbname=" + dbName + " port=" + dbPort + " sslmode=disable"
	var err error
	db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	log.Println("Connected to PostgreSQL database!")

	err = db.AutoMigrate(
		&User{},
		&Workout{},
		&WaterIntake{},
		&DietEntry{},
		&Period{},
		&Award{},
		&Journey{},
		&HealthRecord{},
		&Settings{},
		&Reminder{},
		&FriendRequest{},
		&Friendship{},
		&Activity{},
		&Message{},
		&Badge{},
		&Streak{},
	)
	if err != nil {
		log.Fatalf("failed to auto-migrate models: %v", err)
	}
	log.Println("Database auto-migration complete!")
}

func startReminderChecker() {
	go func() {
		for {
			now := time.Now().Format("2006-01-02 15:04")
			triggeredReminders.Lock()
			var reminders []Reminder
			if err := db.Find(&reminders).Error; err != nil {
				log.Printf("failed to load reminders: %v", err)
			}
			for _, r := range reminders {
				if triggeredReminders.m[r.ID] {
					continue
				}
				if r.Time == now {
					triggeredReminders.m[r.ID] = true
					println("[Reminder] User:", r.UserID, "Message:", r.Message, "Type:", r.Type, "Time:", r.Time)
				}
			}
			triggeredReminders.Unlock()
			time.Sleep(time.Minute)
		}
	}()
}

func getUsers(c *gin.Context) {
	var users []User
	if err := db.Find(&users).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, users)
}

func getUserByID(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}
	var user User
	if err := db.First(&user, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	c.JSON(http.StatusOK, user)
}

func createUser(c *gin.Context) {
	var newUser User
	if err := c.ShouldBindJSON(&newUser); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if newUser.Weight == 0 {
		newUser.Weight = 70
	}
	if newUser.Age == 0 {
		newUser.Age = 18
	}
	if newUser.Sex == "" {
		newUser.Sex = "man"
	}
	if newUser.Height == 0 {
		newUser.Height = 175
	}
	if err := db.Create(&newUser).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, newUser)
}

func updateUser(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}
	var user User
	if err := db.First(&user, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if user.Weight == 0 {
		user.Weight = 70
	}
	if user.Age == 0 {
		user.Age = 18
	}
	if user.Sex == "" {
		user.Sex = "other"
	}
	if user.Height == 0 {
		user.Height = 170
	}
	if err := db.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, user)
}

func deleteUser(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}
	if err := db.Delete(&User{}, id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "User deleted"})
}

func getWorkouts(c *gin.Context) {
	userID := c.GetInt("user_id")
	var workouts []Workout

	start := c.Query("start")
	end := c.Query("end")
	category := c.Query("category")
	typeParam := c.Query("type")

	dbQuery := db.Where("user_id = ?", userID)

	if start != "" {
		dbQuery = dbQuery.Where("created_at >= ?", start)
	}
	if end != "" {
		dbQuery = dbQuery.Where("created_at <= ?", end)
	}
	if category != "" {
		dbQuery = dbQuery.Where("category = ?", category)
	}
	if typeParam != "" {
		dbQuery = dbQuery.Where("type = ?", typeParam)
	}

	if err := dbQuery.Find(&workouts).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, workouts)
}
func getWorkoutByID(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid workout ID"})
		return
	}
	var workout Workout
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&workout).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Workout not found"})
		return
	}
	c.JSON(http.StatusOK, workout)
}
func createWorkout(c *gin.Context) {
	userID := c.GetInt("user_id")
	var newWorkout Workout
	if err := c.ShouldBindJSON(&newWorkout); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	newWorkout.UserID = userID
	if newWorkout.Intensity == "" {
		newWorkout.Intensity = "medium"
	}
	if newWorkout.Location == "" {
		newWorkout.Location = "unspecified"
	}
	if err := db.Create(&newWorkout).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	checkAndAwardBadges(userID) // Award badges after successful workout
	c.JSON(http.StatusCreated, newWorkout)
}
func updateWorkout(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid workout ID"})
		return
	}
	var workout Workout
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&workout).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Workout not found"})
		return
	}
	if err := c.ShouldBindJSON(&workout); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	workout.UserID = userID
	if workout.Intensity == "" {
		workout.Intensity = "medium"
	}
	if workout.Location == "" {
		workout.Location = "unspecified"
	}
	if err := db.Save(&workout).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, workout)
}
func deleteWorkout(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid workout ID"})
		return
	}
	if err := db.Where("id = ? AND user_id = ?", id, userID).Delete(&Workout{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Workout deleted"})
}

func getWaterIntakes(c *gin.Context) {
	userID := c.GetInt("user_id")
	var waterIntakes []WaterIntake
	if err := db.Where("user_id = ?", userID).Find(&waterIntakes).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, waterIntakes)
}
func getWaterIntakeByID(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid water intake ID"})
		return
	}
	var waterIntake WaterIntake
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&waterIntake).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Water intake not found"})
		return
	}
	c.JSON(http.StatusOK, waterIntake)
}
func createWaterIntake(c *gin.Context) {
	userID := c.GetInt("user_id")
	var newWater WaterIntake
	if err := c.ShouldBindJSON(&newWater); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	newWater.UserID = userID
	if err := db.Create(&newWater).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Update streak after creating water intake
	updateStreak(userID, "water")

	c.JSON(http.StatusCreated, newWater)
}
func updateWaterIntake(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid water intake ID"})
		return
	}
	var waterIntake WaterIntake
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&waterIntake).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Water intake not found"})
		return
	}
	if err := c.ShouldBindJSON(&waterIntake); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	waterIntake.UserID = userID
	if err := db.Save(&waterIntake).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, waterIntake)
}
func deleteWaterIntake(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid water intake ID"})
		return
	}
	if err := db.Where("id = ? AND user_id = ?", id, userID).Delete(&WaterIntake{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Water intake deleted"})
}

func getDietEntries(c *gin.Context) {
	userID := c.GetInt("user_id")
	var dietEntries []DietEntry
	if err := db.Where("user_id = ?", userID).Find(&dietEntries).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, dietEntries)
}
func getDietEntryByID(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid diet entry ID"})
		return
	}
	var dietEntry DietEntry
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&dietEntry).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Diet entry not found"})
		return
	}
	c.JSON(http.StatusOK, dietEntry)
}
func createDietEntry(c *gin.Context) {
	userID := c.GetInt("user_id")
	var newDiet DietEntry
	if err := c.ShouldBindJSON(&newDiet); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	newDiet.UserID = userID
	if err := db.Create(&newDiet).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Update streak after creating diet entry
	updateStreak(userID, "diet")

	c.JSON(http.StatusCreated, newDiet)
}
func updateDietEntry(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid diet entry ID"})
		return
	}
	var dietEntry DietEntry
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&dietEntry).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Diet entry not found"})
		return
	}
	if err := c.ShouldBindJSON(&dietEntry); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	dietEntry.UserID = userID
	if err := db.Save(&dietEntry).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, dietEntry)
}
func deleteDietEntry(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid diet entry ID"})
		return
	}
	if err := db.Where("id = ? AND user_id = ?", id, userID).Delete(&DietEntry{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Diet entry deleted"})
}

func getPeriods(c *gin.Context) {
	userID := c.GetInt("user_id")
	var periods []Period
	if err := db.Where("user_id = ?", userID).Find(&periods).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, periods)
}
func getPeriodByID(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid period ID"})
		return
	}
	var period Period
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&period).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Period not found"})
		return
	}
	c.JSON(http.StatusOK, period)
}
func createPeriod(c *gin.Context) {
	userID := c.GetInt("user_id")
	var newPeriod Period
	if err := c.ShouldBindJSON(&newPeriod); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	newPeriod.UserID = userID
	if err := db.Create(&newPeriod).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, newPeriod)
}
func updatePeriod(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid period ID"})
		return
	}
	var period Period
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&period).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Period not found"})
		return
	}
	if err := c.ShouldBindJSON(&period); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	period.UserID = userID
	if err := db.Save(&period).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, period)
}
func deletePeriod(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid period ID"})
		return
	}
	if err := db.Where("id = ? AND user_id = ?", id, userID).Delete(&Period{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Period deleted"})
}

func getAwards(c *gin.Context) {
	userID := c.GetInt("user_id")
	var awards []Award
	if err := db.Where("user_id = ?", userID).Find(&awards).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, awards)
}
func getAwardByID(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid award ID"})
		return
	}
	var award Award
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&award).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Award not found"})
		return
	}
	c.JSON(http.StatusOK, award)
}
func createAward(c *gin.Context) {
	userID := c.GetInt("user_id")
	var newAward Award
	if err := c.ShouldBindJSON(&newAward); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	newAward.UserID = userID
	if err := db.Create(&newAward).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, newAward)
}
func updateAward(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid award ID"})
		return
	}
	var award Award
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&award).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Award not found"})
		return
	}
	if err := c.ShouldBindJSON(&award); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	award.UserID = userID
	if err := db.Save(&award).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, award)
}
func deleteAward(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid award ID"})
		return
	}
	if err := db.Where("id = ? AND user_id = ?", id, userID).Delete(&Award{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Award deleted"})
}

func getJourneys(c *gin.Context) {
	userID := c.GetInt("user_id")
	var journeys []Journey
	if err := db.Where("user_id = ?", userID).Find(&journeys).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, journeys)
}
func getJourneyByID(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid journey ID"})
		return
	}
	var journey Journey
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&journey).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Journey not found"})
		return
	}
	c.JSON(http.StatusOK, journey)
}
func createJourney(c *gin.Context) {
	userID := c.GetInt("user_id")
	var newJourney Journey
	if err := c.ShouldBindJSON(&newJourney); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	newJourney.UserID = userID
	if err := db.Create(&newJourney).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, newJourney)
}
func updateJourney(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid journey ID"})
		return
	}
	var journey Journey
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&journey).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Journey not found"})
		return
	}
	if err := c.ShouldBindJSON(&journey); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	journey.UserID = userID
	if err := db.Save(&journey).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, journey)
}
func deleteJourney(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid journey ID"})
		return
	}
	if err := db.Where("id = ? AND user_id = ?", id, userID).Delete(&Journey{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Journey deleted"})
}

func getHealthRecords(c *gin.Context) {
	userID := c.GetInt("user_id")
	var healthRecords []HealthRecord
	if err := db.Where("user_id = ?", userID).Find(&healthRecords).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, healthRecords)
}
func getHealthRecordByID(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid health record ID"})
		return
	}
	var healthRecord HealthRecord
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&healthRecord).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Health record not found"})
		return
	}
	c.JSON(http.StatusOK, healthRecord)
}
func createHealthRecord(c *gin.Context) {
	userID := c.GetInt("user_id")
	var newRecord HealthRecord
	if err := c.ShouldBindJSON(&newRecord); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	newRecord.UserID = userID
	if newRecord.Date == "" {
		newRecord.Date = time.Now().Format("2006-01-02")
	}
	if err := db.Create(&newRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Update streak if this is a steps record
	if newRecord.Type == "steps" {
		updateStreak(userID, "steps")
	}

	c.JSON(http.StatusCreated, newRecord)
}
func updateHealthRecord(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid health record ID"})
		return
	}
	var healthRecord HealthRecord
	if err := db.Where("id = ? AND user_id = ?", id, userID).First(&healthRecord).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Health record not found"})
		return
	}
	if err := c.ShouldBindJSON(&healthRecord); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	healthRecord.UserID = userID
	if err := db.Save(&healthRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, healthRecord)
}
func deleteHealthRecord(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid health record ID"})
		return
	}
	if err := db.Where("id = ? AND user_id = ?", id, userID).Delete(&HealthRecord{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Health record deleted"})
}

func getReminders(c *gin.Context) {
	userID := c.GetInt("user_id")
	var reminders []Reminder
	if err := db.Where("user_id = ?", userID).Find(&reminders).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, reminders)
}

func createReminder(c *gin.Context) {
	userID := c.GetInt("user_id")
	var newReminder Reminder
	if err := c.ShouldBindJSON(&newReminder); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	newReminder.UserID = userID
	if err := db.Create(&newReminder).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, newReminder)
}

func deleteReminder(c *gin.Context) {
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid reminder ID"})
		return
	}
	if err := db.Where("id = ? AND user_id = ?", id, userID).Delete(&Reminder{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Reminder deleted"})
}

func sendFriendRequest(c *gin.Context) {
	userID := c.GetInt("user_id")
	var req struct {
		ToUserID int `json:"to_user_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || req.ToUserID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid to_user_id"})
		return
	}
	if req.ToUserID == userID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot send request to yourself"})
		return
	}
	var existingFriend Friendship
	if err := db.Where("(user_id1 = ? AND user_id2 = ?) OR (user_id1 = ? AND user_id2 = ?)", userID, req.ToUserID, req.ToUserID, userID).First(&existingFriend).Error; err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Already friends"})
		return
	}
	var existingReq FriendRequest
	if err := db.Where("from_user_id = ? AND to_user_id = ? AND status = ?", userID, req.ToUserID, "pending").First(&existingReq).Error; err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Request already sent"})
		return
	}
	fr := FriendRequest{FromUserID: userID, ToUserID: req.ToUserID, Status: "pending"}
	if err := db.Create(&fr).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, fr)
}

func getFriendRequests(c *gin.Context) {
	userID := c.GetInt("user_id")
	var incoming, outgoing []FriendRequest
	if err := db.Where("to_user_id = ? AND status = ?", userID, "pending").Find(&incoming).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if err := db.Where("from_user_id = ? AND status = ?", userID, "pending").Find(&outgoing).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"incoming": incoming, "outgoing": outgoing})
}

func acceptFriendRequest(c *gin.Context) {
	userID := c.GetInt("user_id")
	var req struct{ RequestID int `json:"request_id"` }
	if err := c.ShouldBindJSON(&req); err != nil || req.RequestID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request_id"})
		return
	}
	var fr FriendRequest
	if err := db.First(&fr, req.RequestID).Error; err != nil || fr.ToUserID != userID || fr.Status != "pending" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Request not found or not allowed"})
		return
	}
	fr.Status = "accepted"
	db.Save(&fr)
	f := Friendship{UserID1: fr.FromUserID, UserID2: fr.ToUserID}
	db.Create(&f)
	c.JSON(http.StatusOK, gin.H{"message": "Friend request accepted"})
}

func rejectFriendRequest(c *gin.Context) {
	userID := c.GetInt("user_id")
	var req struct{ RequestID int `json:"request_id"` }
	if err := c.ShouldBindJSON(&req); err != nil || req.RequestID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request_id"})
		return
	}
	var fr FriendRequest
	if err := db.First(&fr, req.RequestID).Error; err != nil || fr.ToUserID != userID || fr.Status != "pending" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Request not found or not allowed"})
		return
	}
	fr.Status = "rejected"
	db.Save(&fr)
	c.JSON(http.StatusOK, gin.H{"message": "Friend request rejected"})
}

func getFriendsList(c *gin.Context) {
	userID := c.GetInt("user_id")
	var friends []Friendship
	if err := db.Where("user_id1 = ? OR user_id2 = ?", userID, userID).Find(&friends).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	var friendIDs []int
	for _, f := range friends {
		if f.UserID1 == userID {
			friendIDs = append(friendIDs, f.UserID2)
		} else {
			friendIDs = append(friendIDs, f.UserID1)
		}
	}
	var users []User
	if len(friendIDs) > 0 {
		if err := db.Where("id IN ?", friendIDs).Find(&users).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}
	c.JSON(http.StatusOK, users)
}

func getStreakRankings(c *gin.Context) {
	userID := c.GetInt("user_id")
	streakType := c.Query("type") // "steps", "diet", or "water"

	if streakType == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Streak type is required"})
		return
	}

	// Get user's friends
	var friends []Friendship
	if err := db.Where("user_id1 = ? OR user_id2 = ?", userID, userID).Find(&friends).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	var friendIDs []int
	for _, f := range friends {
		if f.UserID1 == userID {
			friendIDs = append(friendIDs, f.UserID2)
		} else {
			friendIDs = append(friendIDs, f.UserID1)
		}
	}

	// Add current user to the list for ranking
	allUserIDs := append([]int{userID}, friendIDs...)

	// Get streaks for all users (including current user)
	var streaks []Streak
	if err := db.Where("user_id IN ? AND type = ?", allUserIDs, streakType).Find(&streaks).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Create a map of user ID to streak current value
	streakMap := make(map[int]int)
	for _, streak := range streaks {
		streakMap[streak.UserID] = streak.Current
	}

	// Sort users by streak (descending)
	type UserStreak struct {
		UserID int `json:"user_id"`
		Streak int `json:"streak"`
	}

	var userStreaks []UserStreak
	for _, uid := range allUserIDs {
		streak := streakMap[uid]
		userStreaks = append(userStreaks, UserStreak{UserID: uid, Streak: streak})
	}

	// Sort by streak descending
	for i := 0; i < len(userStreaks); i++ {
		for j := i + 1; j < len(userStreaks); j++ {
			if userStreaks[i].Streak < userStreaks[j].Streak {
				userStreaks[i], userStreaks[j] = userStreaks[j], userStreaks[i]
			}
		}
	}

	// Find current user's position (1-based ranking)
	var userPosition int
	for i, us := range userStreaks {
		if us.UserID == userID {
			userPosition = i + 1
			break
		}
	}

	// Count friends with higher streaks
	friendsWithHigherStreak := 0
	currentUserStreak := streakMap[userID]
	for _, uid := range friendIDs {
		if streakMap[uid] > currentUserStreak {
			friendsWithHigherStreak++
		}
	}

	// Rating is friends with higher streaks + 1
	rating := friendsWithHigherStreak + 1

	c.JSON(http.StatusOK, gin.H{
		"rating": rating,
		"position": userPosition,
		"total_friends": len(friendIDs),
		"current_streak": currentUserStreak,
	})
}

func register(c *gin.Context) {
	var req struct {
		Name     string `json:"name" binding:"required"`
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data: " + err.Error()})
		return
	}

	var existingUser User
	if err := db.Where("email = ?", req.Email).First(&existingUser).Error; err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email already registered"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	newUser := User{
		Name: req.Name,
		Email: req.Email,
		Password: string(hash),
		Weight: 70,
		Age: 18,
		Sex: "man",
		Height: 175,
	}
	if err := db.Create(&newUser).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"message": "User registered successfully", "user_id": newUser.ID})
}

func login(c *gin.Context) {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	var user User
	if err := db.Where("email = ?", req.Email).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}
	expirationTime := time.Now().Add(24 * time.Hour)
	claims := &Claims{
		UserID: user.ID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(jwtKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"token": tokenString})
}

func authMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenString := c.GetHeader("Authorization")
		if len(tokenString) > 7 && tokenString[:7] == "Bearer " {
			tokenString = tokenString[7:]
		}
		claims := &Claims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			return jwtKey, nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			return
		}
		c.Set("user_id", claims.UserID)
		c.Next()
	}
}

var jwtKey = []byte("qwertyuiop")

type Claims struct {
	UserID int `json:"user_id"`
	jwt.RegisteredClaims
}

func getMe(c *gin.Context) {
	userID := c.GetInt("user_id")
	var user User
	if err := db.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	c.JSON(http.StatusOK, user)
}

func updateMe(c *gin.Context) {
	userID := c.GetInt("user_id")
	var req struct {
		Name   string  `json:"name"`
		Email  string  `json:"email"`
		Weight float64 `json:"weight"`
		Age    int     `json:"age"`
		Sex    string  `json:"sex"`
		Height float64 `json:"height"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	var user User
	if err := db.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	user.Name = req.Name
	user.Email = req.Email
	if req.Weight != 0 {
		user.Weight = req.Weight
	}
	if req.Age != 0 {
		user.Age = req.Age
	}
	if req.Sex != "" {
		user.Sex = req.Sex
	}
	if req.Height != 0 {
		user.Height = req.Height
	}
	if err := db.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, user)
}

func getSettings(c *gin.Context) {
	userID := c.GetInt("user_id")
	var settings Settings
	if err := db.First(&settings, userID).Error; err != nil {
		settings = Settings{UserID: userID, NotificationsEnabled: true, Theme: "light", WaterGoal: 2000, CaloriesGoal: 2000, StepsGoal: 10000}
		if err := db.Create(&settings).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}
	c.JSON(http.StatusOK, settings)
}

func updateSettings(c *gin.Context) {
	userID := c.GetInt("user_id")
	var req struct {
		NotificationsEnabled bool   `json:"notificationsEnabled"`
		Theme               string `json:"theme"`
		WaterGoal             int    `json:"water_goal"`
		CaloriesGoal        int    `json:"calories_goal"`
		StepsGoal             int    `json:"steps_goal"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	var settings Settings
	if err := db.First(&settings, userID).Error; err != nil {
		settings = Settings{UserID: userID, NotificationsEnabled: true, Theme: "light", WaterGoal: 2000, CaloriesGoal: 2000, StepsGoal: 10000}
		if err := db.Create(&settings).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}
	settings.NotificationsEnabled = req.NotificationsEnabled
	settings.Theme = req.Theme
	settings.WaterGoal = req.WaterGoal
	settings.CaloriesGoal = req.CaloriesGoal
	settings.StepsGoal = req.StepsGoal
	if err := db.Save(&settings).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, settings)
}

func searchUsers(c *gin.Context) {
	userID := c.GetInt("user_id")
	q := c.Query("q")
	if len(q) < 2 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Query too short"})
		return
	}
	var friends []Friendship
	if err := db.Where("user_id1 = ? OR user_id2 = ?", userID, userID).Find(&friends).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	friendIDs := map[int]bool{userID: true} // exclude self
	for _, f := range friends {
		if f.UserID1 == userID {
			friendIDs[f.UserID2] = true
		} else {
			friendIDs[f.UserID1] = true
		}
	}
	var users []User
	if err := db.Where("(LOWER(name) LIKE ? OR LOWER(email) LIKE ?)", "%"+q+"%", "%"+q+"%").Find(&users).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	var filtered []User
	for _, u := range users {
		if !friendIDs[u.ID] {
			filtered = append(filtered, u)
		}
	}
	c.JSON(http.StatusOK, filtered)
}

func postActivity(c *gin.Context) {
	userID := c.GetInt("user_id")
	var req struct {
		Type     string `json:"type"`
		Data     string `json:"data"`
		IsPublic bool   `json:"is_public"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || req.Type == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid activity"})
		return
	}
	activity := Activity{
		UserID:   userID,
		Type:     req.Type,
		Data:     req.Data,
		IsPublic: req.IsPublic,
	}
	if err := db.Create(&activity).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, activity)
}

func getFriendsFeed(c *gin.Context) {
	userID := c.GetInt("user_id")
	var friends []Friendship
	if err := db.Where("user_id1 = ? OR user_id2 = ?", userID, userID).Find(&friends).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	friendIDs := []int{}
	for _, f := range friends {
		if f.UserID1 == userID {
			friendIDs = append(friendIDs, f.UserID2)
		} else {
			friendIDs = append(friendIDs, f.UserID1)
		}
	}
	if len(friendIDs) == 0 {
		c.JSON(http.StatusOK, []Activity{})
		return
	}
	var activities []Activity
	if err := db.Where("user_id IN ? AND is_public = ?", friendIDs, true).Order("created_at desc").Find(&activities).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, activities)
}

func isFriend(userID, friendID int) bool {
	var f Friendship
	if err := db.Where("(user_id1 = ? AND user_id2 = ?) OR (user_id1 = ? AND user_id2 = ?)", userID, friendID, friendID, userID).First(&f).Error; err == nil {
		return true
	}
	return false
}

func getChatHistory(c *gin.Context) {
	userID := c.GetInt("user_id")
	friendID, err := strconv.Atoi(c.Param("friend_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid friend_id"})
		return
	}
	if !isFriend(userID, friendID) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Not friends"})
		return
	}
	var messages []Message
	if err := db.Where("(from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?)", userID, friendID, friendID, userID).
		Order("created_at").Find(&messages).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	db.Model(&Message{}).
		Where("from_user_id = ? AND to_user_id = ? AND read = ?", friendID, userID, false).
		Update("read", true)
	c.JSON(http.StatusOK, messages)
}

func postChatMessage(c *gin.Context) {
	userID := c.GetInt("user_id")
	friendID, err := strconv.Atoi(c.Param("friend_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid friend_id"})
		return
	}
	if !isFriend(userID, friendID) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Not friends"})
		return
	}
	var req struct { Content string `json:"content"` }
	if err := c.ShouldBindJSON(&req); err != nil || req.Content == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Empty message"})
		return
	}
	msg := Message{
		SenderID: userID,
		RecipientID: friendID,
		Content:    req.Content,
	}
	if err := db.Create(&msg).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, msg)
}

func getWeeklySummary(c *gin.Context) {
	userID := c.GetInt("user_id")
	start := c.Query("start")
	end := c.Query("end")
	var startTime, endTime time.Time
	var err error
	if start != "" {
		startTime, err = time.Parse("2006-01-02", start)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid start date"})
			return
		}
	} else {
		startTime = time.Now().AddDate(0, 0, -7)
	}
	if end != "" {
		endTime, err = time.Parse("2006-01-02", end)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid end date"})
			return
		}
	} else {
		endTime = time.Now()
	}

	var workouts []Workout
	db.Where("user_id = ? AND created_at >= ? AND created_at <= ?", userID, startTime, endTime).Find(&workouts)
	totalWorkouts := len(workouts)
	totalWorkoutMinutes := 0
	totalWorkoutCalories := 0
	workoutByDay := map[string]int{}
	for _, w := range workouts {
		totalWorkoutMinutes += w.Duration
		totalWorkoutCalories += w.Calories
		day := w.CreatedAt.Format("2006-01-02")
		workoutByDay[day] += w.Calories
	}

	var diets []DietEntry
	db.Where("user_id = ? AND created_at >= ? AND created_at <= ?", userID, startTime, endTime).Find(&diets)
	totalDietCalories := 0
	dietByDay := map[string]int{}
	for _, d := range diets {
		totalDietCalories += d.Calories
		var day string
		if t, ok := any(d).(interface{ GetCreatedAt() time.Time }); ok {
			day = t.GetCreatedAt().Format("2006-01-02")
		} else if createdAtField, ok := any(d).(map[string]interface{}); ok && createdAtField["created_at"] != nil {
			if t, ok := createdAtField["created_at"].(time.Time); ok {
				day = t.Format("2006-01-02")
			}
		}
		if day == "" {
			day = time.Now().Format("2006-01-02")
		}
		dietByDay[day] += d.Calories
	}

	var water []WaterIntake
	db.Where("user_id = ?", userID).Find(&water)
	totalWater := 0
	for _, w := range water {
		totalWater += w.Amount
	}

	var health []HealthRecord
	db.Where("user_id = ? AND type = ?", userID, "steps").Find(&health)
	totalSteps := 0
	for _, h := range health {
		if steps, err := strconv.Atoi(h.Value); err == nil {
			totalSteps += steps
		}
	}

	daily := []gin.H{}
	for d := startTime; !d.After(endTime); d = d.AddDate(0, 0, 1) {
		dateStr := d.Format("2006-01-02")
		daily = append(daily, gin.H{
			"date": dateStr,
			"burned": workoutByDay[dateStr],
			"consumed": dietByDay[dateStr],
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"workouts": totalWorkouts,
		"workout_minutes": totalWorkoutMinutes,
		"workout_calories": totalWorkoutCalories,
		"diet_calories": totalDietCalories,
		"water_ml": totalWater,
		"steps": totalSteps,
		"start": startTime.Format("2006-01-02"),
		"end": endTime.Format("2006-01-02"),
		"daily_calories": daily,
	})
}

func getMonthlySummary(c *gin.Context) {
	userID := c.GetInt("user_id")
	start := c.Query("start")
	end := c.Query("end")
	var startTime, endTime time.Time
	var err error
	if start != "" {
		startTime, err = time.Parse("2006-01-02", start)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid start date"})
			return
		}
	} else {
		startTime = time.Now().AddDate(0, 0, -30)
	}
	if end != "" {
		endTime, err = time.Parse("2006-01-02", end)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid end date"})
			return
		}
	} else {
		endTime = time.Now()
	}

	var workouts []Workout
	db.Where("user_id = ? AND created_at >= ? AND created_at <= ?", userID, startTime, endTime).Find(&workouts)
	totalWorkouts := len(workouts)
	totalWorkoutMinutes := 0
	totalWorkoutCalories := 0
	workoutByDay := map[string]int{}
	for _, w := range workouts {
		totalWorkoutMinutes += w.Duration
		totalWorkoutCalories += w.Calories
		day := w.CreatedAt.Format("2006-01-02")
		workoutByDay[day] += w.Calories
	}

	var diets []DietEntry
	db.Where("user_id = ? AND created_at >= ? AND created_at <= ?", userID, startTime, endTime).Find(&diets)
	totalDietCalories := 0
	dietByDay := map[string]int{}
	for _, d := range diets {
		totalDietCalories += d.Calories
		var day string
		if t, ok := any(d).(interface{ GetCreatedAt() time.Time }); ok {
			day = t.GetCreatedAt().Format("2006-01-02")
		} else if createdAtField, ok := any(d).(map[string]interface{}); ok && createdAtField["created_at"] != nil {
			if t, ok := createdAtField["created_at"].(time.Time); ok {
				day = t.Format("2006-01-02")
			}
		}
		if day == "" {
			day = time.Now().Format("2006-01-02")
		}
		dietByDay[day] += d.Calories
	}

	var water []WaterIntake
	db.Where("user_id = ?", userID).Find(&water)
	totalWater := 0
	for _, w := range water {
		totalWater += w.Amount
	}

	var health []HealthRecord
	db.Where("user_id = ? AND type = ?", userID, "steps").Find(&health)
	totalSteps := 0
	for _, h := range health {
		if steps, err := strconv.Atoi(h.Value); err == nil {
			totalSteps += steps
		}
	}

	daily := []gin.H{}
	for d := startTime; !d.After(endTime); d = d.AddDate(0, 0, 1) {
		dateStr := d.Format("2006-01-02")
		daily = append(daily, gin.H{
			"date": dateStr,
			"burned": workoutByDay[dateStr],
			"consumed": dietByDay[dateStr],
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"workouts": totalWorkouts,
		"workout_minutes": totalWorkoutMinutes,
		"workout_calories": totalWorkoutCalories,
		"diet_calories": totalDietCalories,
		"water_ml": totalWater,
		"steps": totalSteps,
		"start": startTime.Format("2006-01-02"),
		"end": endTime.Format("2006-01-02"),
		"daily_calories": daily,
	})
}

var badgeCriteria = []struct {
	Code  string
	Title string
	Desc  string
	Check func(userID int) bool
}{
	{
		Code:  "steps_10k",
		Title: "10,000 Steps in a Day",
		Desc:  "Walk 10,000 steps in a single day.",
		Check: func(userID int) bool {
			var recs []HealthRecord
			today := time.Now().Format("2006-01-02")
			db.Where("user_id = ? AND type = ? AND date = ?", userID, "steps", today).Find(&recs)
			for _, r := range recs {
				if v, err := strconv.Atoi(r.Value); err == nil && v >= 10000 {
					return true
				}
			}
			return false
		},
	},
	{
		Code:  "streak_7d",
		Title: "7-Day Activity Streak",
		Desc:  "Log a workout every day for 7 days in a row.",
		Check: func(userID int) bool {
			streak := 0
			for i := 0; i < 7; i++ {
				checkDay := time.Now().AddDate(0, 0, -i)
				var count int64
				db.Model(&Workout{}).Where("user_id = ? AND DATE(created_at) = ?", userID, checkDay.Format("2006-01-02")).Count(&count)
				if count > 0 {
					streak++
				} else {
					break
				}
			}
			return streak == 7
		},
	},
	{
		Code:  "workouts_5w",
		Title: "5 Workouts in a Week",
		Desc:  "Complete 5 workouts in a single week.",
		Check: func(userID int) bool {
			weekAgo := time.Now().AddDate(0, 0, -6)
			var count int64
			db.Model(&Workout{}).Where("user_id = ? AND created_at >= ?", userID, weekAgo).Count(&count)
			return count >= 5
		},
	},
}

func checkAndAwardBadges(userID int) {
	for _, crit := range badgeCriteria {
		var existing Badge
		err := db.Where("user_id = ? AND code = ?", userID, crit.Code).First(&existing).Error
		if err == gorm.ErrRecordNotFound && crit.Check(userID) {
			badge := Badge{
				UserID: userID,
				Code:   crit.Code,
				Title:  crit.Title,
				Desc:   crit.Desc,
			}
			db.Create(&badge)
		}
	}
}

func calculateStepsStreak(userID int) int {
	var settings Settings
	if err := db.Where("user_id = ?", userID).First(&settings).Error; err != nil {
		return 0
	}

	streak := 0
	today := time.Now()

	todayStr := today.Format("2006-01-02")
	var totalSteps int
	var records []HealthRecord
	db.Where("user_id = ? AND type = ? AND date = ?", userID, "steps", todayStr).Find(&records)

	for _, record := range records {
		if steps, err := strconv.Atoi(record.Value); err == nil {
			totalSteps += steps
		}
	}

	if totalSteps >= settings.StepsGoal {
		streak = 1
	} else {
		return 0
	}

	for i := 1; i < 365; i++ {
		checkDate := today.AddDate(0, 0, -i)
		dateStr := checkDate.Format("2006-01-02")

		var totalSteps int
		var records []HealthRecord
		db.Where("user_id = ? AND type = ? AND date = ?", userID, "steps", dateStr).Find(&records)

		for _, record := range records {
			if steps, err := strconv.Atoi(record.Value); err == nil {
				totalSteps += steps
			}
		}

		if totalSteps >= settings.StepsGoal {
			streak++
		} else {
			break
		}
	}

	return streak
}

func calculateDietStreak(userID int) int {
	var settings Settings
	if err := db.Where("user_id = ?", userID).First(&settings).Error; err != nil {
		return 0
	}

	streak := 0
	today := time.Now()

	todayStr := today.Format("2006-01-02")
	var totalCalories int
	var entries []DietEntry
	db.Where("user_id = ? AND DATE(created_at) = ?", userID, todayStr).Find(&entries)

	for _, entry := range entries {
		totalCalories += entry.Calories
	}

	if totalCalories <= settings.CaloriesGoal {
		streak = 1
	} else {
		return 0
	}

	for i := 1; i < 365; i++ {
		checkDate := today.AddDate(0, 0, -i)
		dateStr := checkDate.Format("2006-01-02")

		var totalCalories int
		var entries []DietEntry
		db.Where("user_id = ? AND DATE(created_at) = ?", userID, dateStr).Find(&entries)

		for _, entry := range entries {
			totalCalories += entry.Calories
		}

		if totalCalories <= settings.CaloriesGoal {
			streak++
		} else {
			break
		}
	}

	return streak
}

func calculateWaterStreak(userID int) int {
	var settings Settings
	if err := db.Where("user_id = ?", userID).First(&settings).Error; err != nil {
		return 0
	}

	streak := 0
	today := time.Now()

	todayStr := today.Format("2006-01-02")
	var totalWater int
	var intakes []WaterIntake
	db.Where("user_id = ? AND DATE(created_at) = ?", userID, todayStr).Find(&intakes)

	for _, intake := range intakes {
		totalWater += intake.Amount
	}

	if totalWater >= settings.WaterGoal {
		streak = 1
	} else {
		return 0
	}

	for i := 1; i < 365; i++ {
		checkDate := today.AddDate(0, 0, -i)
		dateStr := checkDate.Format("2006-01-02")

		var totalWater int
		var intakes []WaterIntake
		db.Where("user_id = ? AND DATE(created_at) = ?", userID, dateStr).Find(&intakes)

		for _, intake := range intakes {
			totalWater += intake.Amount
		}

		if totalWater >= settings.WaterGoal {
			streak++
		} else {
			break
		}
	}

	return streak
}

func updateStreak(userID int, streakType string) {
	today := time.Now().Format("2006-01-02")

	var streak Streak
	err := db.Where("user_id = ? AND type = ?", userID, streakType).First(&streak).Error

	var currentStreak int
	switch streakType {
	case "steps":
		currentStreak = calculateStepsStreak(userID)
	case "diet":
		currentStreak = calculateDietStreak(userID)
	case "water":
		currentStreak = calculateWaterStreak(userID)
	default:
		return
	}

	if err == gorm.ErrRecordNotFound {
		// Create new streak record
		streak = Streak{
			UserID:   userID,
			Type:     streakType,
			Current:  currentStreak,
			Longest:  currentStreak,
			LastDate: today,
		}
		db.Create(&streak)
	} else {
		streak.Current = currentStreak
		if currentStreak > streak.Longest {
			streak.Longest = currentStreak
		}
		streak.LastDate = today
		db.Save(&streak)
	}
}

func getStreaks(c *gin.Context) {
	userID := c.GetInt("user_id")
	updateStreak(userID, "steps")
	updateStreak(userID, "diet")
	updateStreak(userID, "water")

	var streaks []Streak
	if err := db.Where("user_id = ?", userID).Find(&streaks).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, streaks)
}

func getBadges(c *gin.Context) {
	userID := c.GetInt("user_id")
	var badges []Badge
	if err := db.Where("user_id = ?", userID).Find(&badges).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, badges)
}

func main() {
	err := godotenv.Load()
	if err != nil {
		log.Println("No .env file found or error loading .env file")
	}
	r := gin.Default()

	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowHeaders = []string{"Origin", "Content-Length", "Content-Type", "Authorization"}
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowCredentials = true
	r.Use(cors.New(config))

	r.POST("/register", register)
	r.POST("/login", login)

	auth := r.Group("/")
	auth.Use(authMiddleware())

	auth.GET("/users", getUsers)
	auth.GET("/users/:id", getUserByID)
	auth.POST("/users", createUser)
	auth.PUT("/users/:id", updateUser)
	auth.DELETE("/users/:id", deleteUser)

	auth.GET("/me", getMe)
	auth.PUT("/me", updateMe)

	auth.GET("/workouts", getWorkouts)
	auth.GET("/workouts/:id", getWorkoutByID)
	auth.POST("/workouts", createWorkout)
	auth.PUT("/workouts/:id", updateWorkout)
	auth.DELETE("/workouts/:id", deleteWorkout)

	auth.GET("/water", getWaterIntakes)
	auth.GET("/water/:id", getWaterIntakeByID)
	auth.POST("/water", createWaterIntake)
	auth.PUT("/water/:id", updateWaterIntake)
	auth.DELETE("/water/:id", deleteWaterIntake)

	auth.GET("/diet", getDietEntries)
	auth.GET("/diet/:id", getDietEntryByID)
	auth.POST("/diet", createDietEntry)
	auth.PUT("/diet/:id", updateDietEntry)
	auth.DELETE("/diet/:id", deleteDietEntry)

	auth.GET("/periods", getPeriods)
	auth.GET("/periods/:id", getPeriodByID)
	auth.POST("/periods", createPeriod)
	auth.PUT("/periods/:id", updatePeriod)
	auth.DELETE("/periods/:id", deletePeriod)

	auth.GET("/awards", getAwards)
	auth.GET("/awards/:id", getAwardByID)
	auth.POST("/awards", createAward)
	auth.PUT("/awards/:id", updateAward)
	auth.DELETE("/awards/:id", deleteAward)

	auth.GET("/journeys", getJourneys)
	auth.GET("/journeys/:id", getJourneyByID)
	auth.POST("/journeys", createJourney)
	auth.PUT("/journeys/:id", updateJourney)
	auth.DELETE("/journeys/:id", deleteJourney)

	auth.GET("/healthrecords", getHealthRecords)
	auth.GET("/healthrecords/:id", getHealthRecordByID)
	auth.POST("/healthrecords", createHealthRecord)
	auth.PUT("/healthrecords/:id", updateHealthRecord)
	auth.DELETE("/healthrecords/:id", deleteHealthRecord)

	auth.GET("/reminders", getReminders)
	auth.POST("/reminders", createReminder)
	auth.DELETE("/reminders/:id", deleteReminder)

	auth.GET("/settings", getSettings)
	auth.PUT("/settings", updateSettings)

	r.POST("/friends/request", authMiddleware(), sendFriendRequest)
	r.GET("/friends/requests", authMiddleware(), getFriendRequests)
	r.POST("/friends/accept", authMiddleware(), acceptFriendRequest)
	r.POST("/friends/reject", authMiddleware(), rejectFriendRequest)
	r.GET("/friends", authMiddleware(), getFriendsList)
	r.GET("/friends/list", authMiddleware(), getFriendsList)
	r.GET("/streaks/rankings", authMiddleware(), getStreakRankings)
	r.GET("/users/search", authMiddleware(), searchUsers)
	r.POST("/activity", authMiddleware(), postActivity)
	r.GET("/feed/friends", authMiddleware(), getFriendsFeed)
	r.GET("/chat/:friend_id", authMiddleware(), getChatHistory)
	r.POST("/chat/:friend_id", authMiddleware(), postChatMessage)
	auth.GET("/summary/weekly", getWeeklySummary)
	auth.GET("/summary/monthly", getMonthlySummary)
	auth.GET("/badges", authMiddleware(), getBadges)
	auth.GET("/streaks", authMiddleware(), getStreaks)

	initDB()
	startReminderChecker()
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	r.Run(":8080")
}