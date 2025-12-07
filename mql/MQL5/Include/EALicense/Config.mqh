//+------------------------------------------------------------------+
//|                                                      Config.mqh   |
//|                                    EA License Management System   |
//+------------------------------------------------------------------+
#property copyright "EA License System"
#property version   "1.00"

// API Configuration - Production URL
#define LICENSE_API_ENDPOINT "https://ea-license-system-one.vercel.app"

// Validation Settings
#define VALIDATION_INTERVAL_HOURS 12
#define DEFAULT_GRACE_PERIOD_HOURS 24

// EA Information (override in each EA)
#define EA_CODE "example_ea"
#define EA_VERSION "1.0.0"
