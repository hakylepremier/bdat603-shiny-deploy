library(shiny)
library(tidyverse)
library(lubridate)

# -------------------------------
# 1. Simulate class data
# -------------------------------
simulate_online_sales <- function(n = 50000, seed = 603170126) {
  set.seed(seed)
  
  id <- 1:n
  user_id <- sample(1:(n / 2), n, replace = TRUE)
  product_id <- sample(1:(n / 5), n, replace = TRUE)
  
  ip_address <- paste0(
    sample(1:255, n, TRUE), ".",
    sample(1:255, n, TRUE), ".",
    sample(1:255, n, TRUE), ".",
    sample(1:255, n, TRUE)
  )
  
  sex <- sample(c("Male", "Female"), n, TRUE)
  
  continent <- sample(
    c("Africa", "Europe", "Asia", "North America",
      "South America", "Oceania"),
    n, TRUE,
    prob = c(0.20, 0.18, 0.25, 0.22, 0.10, 0.05)
  )
  
  education <- sample(
    c("None", "Primary", "Secondary", "Tertiary"),
    n, TRUE,
    prob = c(0.10, 0.25, 0.35, 0.30)
  )
  
  age <- pmax(18, round(rnorm(n, mean = 35, sd = 12)))
  
  base_income <- case_when(
    education == "None" ~ 1200,
    education == "Primary" ~ 2200,
    education == "Secondary" ~ 3800,
    education == "Tertiary" ~ 6500
  )
  
  income <- round(
    base_income *
      ifelse(sex == "Male", 1.1, 1) *
      ifelse(continent %in% c("Europe", "North America"), 1.3, 1) *
      rlnorm(n, 0, 0.3),
    2
  )
  
  category <- sample(
    c("Electronics", "Cosmetics", "Stationery", "Clothing",
      "Groceries", "Furniture", "Books"),
    n, TRUE
  )
  
  base_price <- case_when(
    category == "Electronics" ~ 600,
    category == "Furniture" ~ 450,
    category == "Clothing" ~ 120,
    category == "Cosmetics" ~ 90,
    category == "Groceries" ~ 40,
    category == "Books" ~ 60,
    TRUE ~ 30
  )
  
  promotion <- sample(c(0, 1), n, TRUE, prob = c(0.75, 0.25))
  discount_rate <- ifelse(promotion == 1, runif(n, 0.05, 0.30), 0)
  
  price <- round(
    base_price * rlnorm(n, 0, 0.4) * (1 - discount_rate),
    2
  )
  
  quantity <- sample(1:5, n, TRUE)
  
  customer_type <- sample(c("New", "Returning"), n, TRUE, prob = c(0.35, 0.65))
  
  device_type <- sample(
    c("Mobile", "Desktop", "Tablet"),
    n, TRUE,
    prob = c(0.60, 0.30, 0.10)
  )
  
  browser <- sample(
    c("Chrome", "Firefox", "Safari", "Edge", "Opera"),
    n, TRUE
  )
  
  session_duration <- round(
    rlnorm(
      n,
      meanlog = ifelse(device_type == "Desktop", 3.4, 3.0),
      sdlog = 0.4
    ),
    1
  )
  
  expenditure <- round(
    price * quantity *
      (1 + log(income) / max(log(income))) *
      ifelse(customer_type == "Returning", 1.15, 1) *
      rlnorm(n, 0, 0.15),
    2
  )
  
  order_date <- sample(
    seq.Date(as.Date("2023-01-01"), as.Date("2024-12-31"), by = "day"),
    n, TRUE
  )
  
  delivery_days <- pmax(
    1,
    round(
      rnorm(
        n,
        mean = ifelse(continent %in% c("Europe", "North America"), 5, 10),
        sd = 2
      )
    )
  )
  
  delivery_date <- order_date + days(delivery_days)
  weekend_order <- wday(order_date) %in% c(1, 7)
  
  payment_method <- sample(
    c("Card", "Mobile Money", "Bank Transfer", "Crypto"),
    n, TRUE
  )
  
  customer_rating <- pmin(
    5,
    pmax(
      1,
      round(
        4.5 -
          0.15 * delivery_days +
          0.0005 * expenditure +
          rnorm(n, 0, 0.5)
      )
    )
  )
  
  data.frame(
    id, user_id, product_id, ip_address,
    sex, age, continent, education,
    income, category, promotion, discount_rate,
    price, quantity, expenditure,
    customer_type, device_type, browser,
    session_duration, payment_method,
    weekend_order,
    order_date, delivery_date, delivery_days,
    customer_rating
  )
}

sales_data <- simulate_online_sales(n = 50000, seed = 22429389)

# -------------------------------
# 2. Bernoulli sample equivalent for app use
# -------------------------------
bernoulli_sample <- sales_data %>%
  slice_sample(prop = 0.1)

# -------------------------------
# 3. Small helper objects for UI
# -------------------------------
date_limits <- bernoulli_sample %>%
  summarise(
    min_date = min(order_date, na.rm = TRUE),
    max_date = max(order_date, na.rm = TRUE)
  )

category_choices <- bernoulli_sample %>%
  distinct(category) %>%
  arrange(category) %>%
  pull(category)

device_choices <- bernoulli_sample %>%
  distinct(device_type) %>%
  arrange(device_type) %>%
  pull(device_type)

# -------------------------------
# 4. UI
# -------------------------------
ui <- fluidPage(
  titlePanel("Promotional Impact on Spending Behavior Dashboard"),
  
  sidebarLayout(
    sidebarPanel(
      selectInput(
        inputId = "category",
        label = "Select Product Category",
        choices = category_choices
      ),
      
      selectInput(
        inputId = "device_type",
        label = "Select Device Type",
        choices = device_choices
      ),
      
      dateRangeInput(
        inputId = "dates",
        label = "Choose Order Date Range",
        start = date_limits$min_date,
        end = date_limits$max_date
      ),
      
      actionButton(
        inputId = "run_analysis",
        label = "Generate Dashboard"
      ),
      
      br(),
      hr(),
      p(strong("Author:"), "Humphrey Kweku Ampong Yeboah"),
      p(strong("Course:"), "BDAT 603")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel(
          "Plots",
          fluidRow(
            column(6, plotOutput("avgExpPlot")),
            column(6, plotOutput("ratingPlot"))
          )
        ),
        
        tabPanel(
          "Summary Tables",
          h4("Table 1: Spending Summary by Promotion"),
          tableOutput("summaryTable1"),
          br(),
          h4("Table 2: Payment Method Distribution by Promotion"),
          tableOutput("summaryTable2")
        )
      )
    )
  )
)

# -------------------------------
# 5. Server
# -------------------------------
server <- function(input, output) {
  
  filtered_data <- eventReactive(input$run_analysis, {
    start_date <- as.Date(input$dates[1])
    end_date   <- as.Date(input$dates[2])
    
    bernoulli_sample %>%
      filter(
        category == input$category,
        device_type == input$device_type,
        order_date >= start_date,
        order_date <= end_date
      )
  }, ignoreInit = TRUE)
  
  # Plot 1: Average expenditure by promotion
  output$avgExpPlot <- renderPlot({
    req(filtered_data())
    
    plot_data <- filtered_data() %>%
      group_by(promotion) %>%
      summarise(
        avg_expenditure = mean(expenditure, na.rm = TRUE),
        transactions = n()
      ) %>%
      mutate(
        promotion = ifelse(promotion == 1, "Promotional", "Non-promotional")
      )
    
    ggplot(plot_data, aes(x = promotion, y = avg_expenditure, fill = promotion)) +
      geom_col(width = 0.65) +
      geom_text(
        aes(label = round(avg_expenditure, 2)),
        vjust = -0.3,
        fontface = "bold"
      ) +
      labs(
        title = paste("Average Expenditure by Promotion:", input$category),
        subtitle = paste("Device Type:", input$device_type),
        x = "Promotion Status",
        y = "Average Expenditure"
      ) +
      theme_classic() +
      theme(legend.position = "none")
  })
  
  # Plot 2: Customer rating distribution by promotion
  output$ratingPlot <- renderPlot({
    req(filtered_data())
    
    plot_data <- filtered_data() %>%
      group_by(promotion, customer_rating) %>%
      tally() %>%
      mutate(
        promotion = ifelse(promotion == 1, "Promotional", "Non-promotional"),
        customer_rating = factor(customer_rating)
      )
    
    ggplot(plot_data, aes(x = customer_rating, y = n, fill = promotion)) +
      geom_col(position = "dodge") +
      labs(
        title = "Customer Rating Distribution by Promotion",
        x = "Customer Rating",
        y = "Number of Transactions",
        fill = "Promotion"
      ) +
      theme_classic()
  })
  
  # Table 1: Numerical summary by promotion
  output$summaryTable1 <- renderTable({
    req(filtered_data())
    
    filtered_data() %>%
      group_by(promotion) %>%
      summarise(
        Transactions = n(),
        Mean_Expenditure = mean(expenditure, na.rm = TRUE),
        Median_Expenditure = median(expenditure, na.rm = TRUE),
        SD_Expenditure = sd(expenditure, na.rm = TRUE),
        Mean_Discount = mean(discount_rate, na.rm = TRUE),
        Mean_Rating = mean(customer_rating, na.rm = TRUE)
      ) %>%
      mutate(
        promotion = ifelse(promotion == 1, "Promotional", "Non-promotional"),
        across(where(is.numeric), ~ round(.x, 2))
      ) %>%
      rename(`Promotion Status` = promotion)
  }, digits = 2)
  
  # Table 2: Payment method distribution by promotion
  output$summaryTable2 <- renderTable({
    req(filtered_data())
    
    filtered_data() %>%
      group_by(payment_method, promotion) %>%
      tally() %>%
      mutate(
        promotion = ifelse(promotion == 1, "Promotional", "Non_Promotional")
      ) %>%
      pivot_wider(
        names_from = promotion,
        values_from = n,
        values_fill = 0
      ) %>%
      arrange(desc(Promotional + Non_Promotional)) %>%
      rename(`Non-promotional` = Non_Promotional)
  }, digits = 2)
}

# -------------------------------
# 6. Run app
# -------------------------------
shinyApp(ui = ui, server = server)