build_about_panel <- function() {
  tags$div(class = "tab-pane fade", id = "about-panel", role = "tabpanel",
    tags$div(class = "container mt-4",

      tags$h3("About This Project"),
      tags$h5("The Housing, Health, and Wealth Analyzer", class = "text-muted mb-4"),

      tags$p(
        "This dashboard operationalizes the Maryland Department of Housing and Community ",
        "Development's (DHCD)", 
        tags$strong(
          "Housing, Health, and Wealth (HHW) framework",
          .noWS = c("after")
        ),
        "—a tool for understanding how housing conditions, health outcomes, and ",
        "wealth-building opportunities vary across Maryland communities."
      ),
      tags$p(
        "The framework supports DHCD's mission of ensuring every Marylander has the ",
        "opportunity to live and prosper in affordable, livable, and just communities. It's ",
        "built for DHCD analysts and policymakers who need to identify areas of need, track ",
        "progress over time, and evaluate whether improvements reflect genuine gains for the ",
        "people already living in a community, rather than displacement."
      ),
      tags$p(
        "The maps and scores in this dashboard summarize each Maryland census tract across ",
        "three domains, plus a fourth index that flags displacement risk."
      ),

      tags$hr(),

      tags$h4("The Three Core Indices"),
      tags$div(class = "row mt-3",
        tags$div(class = "col-md-4 mb-3",
          tags$div(class = "card h-100",
            tags$div(class = "card-body",
              tags$h5(class = "card-title", "Housing Stability Index (HSI)"),
              tags$p(class = "card-text",
                "Measures how secure and stable housing conditions are in a tract, based on ",
                "foreclosure activity, cost burden, overcrowding, and vacancy rates."
              )
            )
          )
        ),
        tags$div(class = "col-md-4 mb-3",
          tags$div(class = "card h-100",
            tags$div(class = "card-body",
              tags$h5(class = "card-title", "Health Outcomes Index (HOI)"),
              tags$p(class = "card-text",
                "Reflects health conditions closely tied to housing quality, including low ",
                "birth weight, asthma, myocardial infarction rates, lead exposure risk (via ",
                "pre-1980 housing stock), and insurance coverage."
              )
            )
          )
        ),
        tags$div(class = "col-md-4 mb-3",
          tags$div(class = "card h-100",
            tags$div(class = "card-body",
              tags$h5(class = "card-title", "Wealth Accumulation Index (WAI)"),
              tags$p(class = "card-text",
                "Captures a community's opportunity to build wealth through homeownership, ",
                "home value appreciation, income and employment, and access to credit, ",
                "including small business lending."
              )
            )
          )
        )
      ),

      tags$p(
        "Each index is scored from 0–100, with higher scores indicating better outcomes. ",
        "Scores are also converted into within-year percentile ranks, so you can see how a ",
        "tract compares to others across the state in the same year."
      ),

      tags$div(class = "alert alert-warning",
        tags$strong("Displacement Risk Assessment: "),
        tags$span(
          "A companion score (0–3) that flags tracts showing signs of demographic turnover—",
          .noWS = c("after"),
        ),
        "shifts in minority population share, rising educational attainment, and increased ",
        "school withdrawal rates. This helps distinguish neighborhoods that are genuinely ",
        "improving for existing residents from those where rising scores might reflect ",
        "displacement instead."
      ),

      tags$hr(),

      tags$h4("Data & Methodology"),
      tags$p(
        "All figures are built at the census tract level using data from a range of public and ",
        "restricted-access sources, including the Census Bureau, HUD, the Maryland Department ",
        "of Labor, and the Maryland State Department of Education."
      ),
      tags$p(
        "To ensure this tool is reliable for policy decisions, strict data quality standards are enforced:"
      ),
      tags$ul(
        tags$li(tags$strong("Trend Accuracy: "), "Historical data has been carefully aligned to current 2020 Census boundaries to ensure accurate tracking over time."),
        tags$li(tags$strong("Privacy & Reliability: "), "Where data is suppressed to protect resident privacy, or where sample sizes are too small to be statistically reliable, it is conservatively estimated or excluded rather than risk misleading scores.")
      ),

      tags$hr(),

      tags$h4("Questions & Resources"),
      tags$p(
        "This project is maintained by the ", tags$strong("Division of Just Communities"),
        " at the Maryland Department of Housing and Community Development."
      ),
      tags$p(
        "For policy questions, reach out to Scott Pawley via ",
        tags$a(href = "https://www.linkedin.com/in/scott-pawley/", target = "_blank", "LinkedIn"),
        " or visit the ",
        tags$a(href = "https://dhcd.maryland.gov/Just-Communities/Pages/default.aspx", target = "_blank", "Just Communities website.")
      ),
      tags$p(class = "text-muted",
        "For technical users, the underlying code, data pipelines, and detailed ",
        "methodology are fully open-source and available on ",
        tags$a(href = "https://github.com/beyond-reality-dev/Housing-Health-Wealth", target = "_blank", "GitHub.")
      )
    )
  )
}