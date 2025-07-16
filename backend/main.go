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
	ID    int    `json:"id" gorm:"primaryKey;autoIncrement"`
	Name  string `json:"name" gorm:"not null"`
	Email string `json:"email" gorm:"unique;not null"`
}

type Workout struct {
	ID       int    `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID   int    `json:"user_id" gorm:"index;not null"`
	Type     string `json:"type" gorm:"not null"`
	Duration int    `json:"duration"`
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
	UserID              int    `json:"user_id" gorm:"primaryKey"`
	NotificationsEnabled bool   `json:"notificationsEnabled"`
	Theme               string `json:"theme"`
}

type Reminder struct {
	ID      int    `json:"id" gorm:"primaryKey;autoIncrement"`
	UserID  int    `json:"user_id" gorm:"index;not null"`
	Time    string `json:"time"`
	Message string `json:"message"`
	Type    string `json:"type"`
}

var userPasswords = map[int]string{}

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

// --- User CRUD ---
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

// --- Workout CRUD ---
func getWorkouts(c *gin.Context) {
	userID := c.GetInt("user_id")
	var workouts []Workout
	if err := db.Where("user_id = ?", userID).Find(&workouts).Error; err != nil {
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
	if err := db.Create(&newWorkout).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
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

// --- WaterIntake CRUD ---
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

// --- DietEntry CRUD ---
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

// --- Period CRUD ---
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

// --- Award CRUD ---
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

// --- Journey CRUD ---
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

// --- HealthRecord CRUD ---
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
	var newHealth HealthRecord
	if err := c.ShouldBindJSON(&newHealth); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	newHealth.UserID = userID
	if err := db.Create(&newHealth).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, newHealth)
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

// --- Reminder CRUD ---
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

// Registration endpoint
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

	// Check if user exists
	var existingUser User
	if err := db.Where("email = ?", req.Email).First(&existingUser).Error; err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email already registered"})
		return
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	newUser := User{
		Name:  req.Name,
		Email: req.Email,
	}
	if err := db.Create(&newUser).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	userPasswords[newUser.ID] = string(hash)
	c.JSON(http.StatusCreated, gin.H{"message": "User registered successfully", "user_id": newUser.ID})
}

// Login endpoint
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
	hash := userPasswords[user.ID]
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}
	// Generate JWT
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

// JWT Middleware
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

var jwtKey = []byte("your_secret_key")

type Claims struct {
	UserID int `json:"user_id"`
	jwt.RegisteredClaims
}

// Get current user info
func getMe(c *gin.Context) {
	userID := c.GetInt("user_id")
	var user User
	if err := db.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	c.JSON(http.StatusOK, user)
}

// Update current user info
func updateMe(c *gin.Context) {
	userID := c.GetInt("user_id")
	var req struct {
		Name  string `json:"name"`
		Email string `json:"email"`
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
		// Default settings
		settings = Settings{UserID: userID, NotificationsEnabled: true, Theme: "light"}
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
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	var settings Settings
	if err := db.First(&settings, userID).Error; err != nil {
		// Default settings
		settings = Settings{UserID: userID, NotificationsEnabled: true, Theme: "light"}
		if err := db.Create(&settings).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}
	settings.NotificationsEnabled = req.NotificationsEnabled
	settings.Theme = req.Theme
	if err := db.Save(&settings).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, settings)
}

func main() {
	err := godotenv.Load()
	if err != nil {
		log.Println("No .env file found or error loading .env file")
	}
	r := gin.Default()

	// Configure CORS to allow Authorization header
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

	initDB()
	startReminderChecker()
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	r.Run(":8080")
}