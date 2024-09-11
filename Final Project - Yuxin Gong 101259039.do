

*******************************************************************************************************************
*** Project title: How does the consumers’ subjective mental state impact their households’ consumption pattern ***
*******************************************************************************************************************
* Created by Yuxin Gong
* Student Number: 101259039


* This code performs the data analysis for the final project of Yuxin Gong
	* set your working directory and folders before using
	* or change the paths for code to run

clear 
set more off
capture log close
set type double

	*** Set your working directory here
		
global path = "D:/ADA/Final Project"
global output = "$path/Output"
global input = "$path/Input"
global temp = "$path/Temp"
global figures = "$path/Figures"
global clean = "$path/Clean"

log using "$path/Logs/Final Project", replace




*****************************
***** 1. Data Cleaning  *****
*****************************
          
		  *************************************
          *** 1 (a) Cleaning "famconf" file ***
          *************************************
		  * This is the only file that contains the variable "family size". I want to only keep the family size information for each family ID.
		  use "$input/ecfps2018famconf_202008.dta", clear
		  codebook pid
		  * There are 58,504 unique observations in this dataset and no missing value for pid variable.
		  
		  *keep fid18 familysize18
		  sort fid18
		  by fid18: gen filter = _n
		  by fid18: egen check = max(filter) 
		  keep if filter == 1
		  drop filter
		  sum familysize18
		  
		  keep familysize18 fid18 check 

		  preserve
		  collapse (sum) familysize18 
		  list
		  restore 
		  * As is shown, the total number of people in all surveyed households is 53,121, which is less than the num of total observations. The reason is unknown because no information in the data documentation recorded how familysize variable was collected. To ensure the best accuracy, I decide to drop those families whose recorded familysize is not the same as the actual recorded number of family members.
		  
		  keep if familysize18 == check
		  drop check
		  sum familysize18
		  save "$temp/familysize", replace
		  

          *********************************
          *** 1 (b) Clean "person" file ***
          *********************************
		  
		  * The "Person" file includes the variables used to generate the main x variables and some of the control variables. In this section, I will use this dataset to generate the main x variables (mental health, life satisfaction, and confidence in the future) and control variables (demographics, the number of children, and the number of old people). 
		  
		  
		  ***********
		  *** (i) ***
		  ***********
		  
		  * Generate the variable for the number of children/old people in a household *
		  * Since the children's answers are in a different dataset, to make sure the accuracy of the number of the children, I will append the childproxy dataset to the person dataset and make sure the variables I'll use have the same variable names.
		  use "$input/ecfps2018person_202012.dta", clear
		  append using "$input/ecfps2018childproxy_202012.dta"
		  * Before I append, I made sure the variables needed for this process have the same names (i.e. the variables fid18 and age), so that I don't lose data.
		  sum age
		  *in this survey, for many questions with numerical answers, the researchers use -8 representing "missing". it'll disrupt the statistical description. 
		  replace age = . if age == -8 
		  sum age
		  * Now all the missing values are ".". The mean of the age is 
		  histogram age, discrete frequency
		  graph export "$figures/age_frequency.pdf", replace
		  tab age
		  * the people aged above 65 takes up 13.33% of the surveyed population, which proves that China is currently an ageing society (if more than 7%, a society is considered as an ageing society.).
		  
		  gen child_flag = 1 if age < 18
		  gen old_flag = 1 if age > 65
		  collapse (sum) child_n = child_flag (sum) old_n = old_flag, by (fid18)
		  label var child_n "The number of children in the household"
		  label var old_n "The number of old people in the household"
		  save "$temp/child_old_n", replace
		  

		  ************
		  *** (ii) ***
		  ************	  
		  * Now, generate the variables "attitude toward life", "life satisfaction", and "confidence in future" *
		  use "$input/ecfps2018person_202012.dta", clear 
		  * Generate "attitude toward life" variable using variables qm101m - qm110m 
		  * For these variables, 1-strongly disagree, 2-disagree, 3-agree, 4-strongly agree, 5-neutral. I need to re-order them from 1-5 respectively representing 1-strongly disagree, 2-disagree, 3-neutral, 4-agree, 5-strongly agree, so that the bigger the ultimate number of mental health, the better the mental health.
		  * Except for qm103m and qm105m that basically measure how bad the respondent is feeling, the others measure how good the respondent is feeling. So I choose to revserse the response of qm103m and qm105m.
		  describe
		  foreach var of varlist qm103m qm105m {
		  gen `var'_replace = 5 if `var' == 1
		      replace `var'_replace = 4 if `var' == 2
			  replace `var'_replace = 3 if `var' == 5
			  replace `var'_replace = 1 if `var' == 4
			  replace `var'_replace = 2 if `var' == 3
		  }	  
		  drop qm103m qm105m
		  describe
		  
		  foreach var of varlist qm101m-qm110m{
		  di "`var'"
		  gen `var'_replace = 1 if `var' == 1
		      replace `var'_replace = 2 if `var' == 2
			  replace `var'_replace = 3 if `var' == 5
			  replace `var'_replace = 4 if `var' == 3
			  replace `var'_replace = 5 if `var' == 4
		  }
		  describe
		  egen attitude = rowmean(qm103m_replace-qm110m_replace)
		  label var attitude "Respondent's average attitude towards life. A bigger number means more positiveness"
		  sum attitude
		  * the mean is 3.44, only 1806 observations. This could lead to a sharp decrease in the number of observations in later-on regression analysis because of the next steps of merging.
		  save "$temp/attitude", replace
		  
		  
		  *************
		  *** (iii) ***
		  *************
		  *use "$temp/attitude", clear
		  * Now generate life satisfaction variable and "confidence in future" variable

		  clonevar life_sat = qn12012
		  clonevar future_con = qn12016
          
		  describe
		  
		  tab life_sat 
		  tab future_con
		  *br life_sat future_con
		  * "Not applicable" (-8) , unknown (-2) and refuse (-1)should be treated as missing values.
		  foreach var of varlist life_sat future_con{
		  replace `var' = . if `var' <0
		  }
		  
		  sum life_sat future_con

		  * As of now, I have all the main independent variables ready
		  save "$temp/main_inde", replace
		  
		  ************
		  *** (iv) ***
		  ************
		  * Now I keep the independent variables as well as the control variables in this dataset
		  use "$temp/main_inde", clear
		  keep fid18 pid attitude life_sat future_con age gender qea0 w01
		  
		  rename qea0 marriage
		  tab marriage
		  sum marriage
		  codebook marriage
		  replace marriage = . if marriage == -8
		  replace marriage = 0 if marriage == 1 | marriage == 4 | marriage == 5 
		  replace marriage = 1 if marriage == 3 | marriage == 2
		  rename marriage married
		  label define married 1"married" 0"unmarried"
		  label value married married 
		  label var married "Whether the respondent is married"
		  
		  rename w01 edu
		  tab edu
		  codebook edu
		  * br edu
		  * "Not applicable" (-8) , unknown (-2) and resuse (-1)should be treated as missing values.
		  replace edu = . if edu < 0
		  tab edu
		  codebook edu
		  replace edu = 0 if edu == 0 | edu == 10
		  replace edu = 1 if edu == 3 | edu == 4 | edu == 5
		  replace edu = 2 if edu == 6 | edu == 7 | edu == 8 | edu == 9
		  label define edu 0"uneducated" 1"middle_edu" 2"high_edu"
		  label value edu edu
		  label var edu "The education level of the respondent"
		  sum edu
		  tab edu
		  
		  * br gender
		  * the male is "1" and female is "0"
		  rename gender male 
		  label var male "The gender of the respondent"
		  
		  save "$clean/person_clean", replace
		  
		  
		  **********************************
          *** 1 (c) Clean "famecon" file ***
          **********************************
		  
		  ***********
		  *** (i) ***
		  ***********
		  * Now generate the dependent variables and some of the control variables.
		  use "$input/ecfps2018famecon_202101.dta", clear
		  keep fid18 provcd18 urban18 finc fp3-resp4pid ft1 fincexp fu100
		  drop fp5070 resp4
		  
		  codebook provcd18
		  * No need to clean
		  codebook urban18
		  replace urban18 = . if urban18 == -9
		  
		  
		  * Make sure the variables for later-on merge have the same name
		  rename resp4pid pid
		  codebook pid
		  * The missing values are in the value of "-8"
		  replace pid = . if pid == -8
		  codebook pid
		  
		  *br fp3-fp518
		  * "Not applicable" (-8) , unknown (-2) and resuse (-1)should be treated as missing values.
		  foreach var of varlist fp3-fp518 ft1 finc{
		  di "`var'"
		  replace `var' = . if `var' <0
		  } 
		  
		  * variables fp3-fp407 are monthly expenditure. need to turn them into annual expenditure.
		  foreach var of varlist fp3-fp407{
		  di "`var'"
		  gen `var'X12 = `var'*12
		  }
		  
		  egen total_exp = rowtotal(fp3X12-fp407X12 fp501-fp518)
		  label var total_exp "Total expenditure in past 12 months"
		  
		  rename fp3X12 food
		  label var food "Expenditure on food in past 12 months"
		  
		  rename fp301X12 dineout
		  label var dineout "Expenditure on dining out in past 12 months"
		  
		  gen eatathome = food - dineout
		  label var eatathome "Expenditure on eating at home in past 12 months"
		  
		  clonevar clothing = fp501
		  clonevar entertainment = fp502
		  clonevar travel = fp503
		  
		  egen housing_trans = rowtotal (fp504-fp506 fp401X12-fp407X12)
		  label var housing_trans "Expenditure on housing and transportation in past 12 months"
		  
		  egen durable = rowtotal (fp507-fp509)
		  label var durable "Expenditure on durable goods in past 12 months"
		  
		  clonevar edu_exp = fp510
		  clonevar med = fp511
		  
		  egen percare_insurance = rowtotal(fp512-fp514)
		  label var percare_insurance "Expenditure on personal care and insurance in past 12 months"
		  
		  egen help_out = rowtotal (fp515-fp517)
		  label var help_out "Expenditure on giving out help in past 12 months"
		  
		  clonevar otherexp = fp518
		  
		  clonevar savings = ft1
		  
		  /*
		  foreach var of varlist food-otherexp{
		  label var `var' "Annual expenditure on `var'"
		  }
		  label var total_exp "Annual total expenditure"
		  */
		  
		  clonevar big_event = fu100
		  *br big_event
		  codebook big_event
		       replace big_event = 0 if big_event == 5
			   replace big_event = . if big_event < 0

		  *br finc
		  sum finc
		  * All the values in finc are normal and makes sense
		  
		  * br fincexp
		  * Since here, only those whose income is less than expenditure will be asked, so those "Not applicable" means their income is more than expenditure, therefore should be 0 to this question.
		  /*
		  codebook fincexp
		  replace fincexp = . if fincexp == -1
		  replace fincexp = 0 if fincexp == -8 | fincexp == 5
		  codebook fincexp
		  This variable will not be used in later regression
		  */
		  drop fincexp
		  
		  drop fp3-fp518
		  drop ft1 fu100
		  drop fp401X12-fp407X12
		  
		  save "$temp/famecon_beforefinal", replace
		  
		  ************
		  *** (ii) ***
		  ************
		  * use "$temp/famecon_beforefinal", clear
		  * genertate percentage variables
		  gen noness_perc = [1 - (eatathome + clothing + housing_trans + med)/total_exp]*100
		  * Only expenditure on eating at home, clothing, housing and transportation, and medicine is essential because they have a low elasticity of demand, i.e. people spend this money no matter what. 
		  label var noness_perc "Percentage of expenditure on non-essential goods out of total annual expenditure"
		  sum noness_perc
		  * It can be seen that the max value is 99.85%, which might be an abnormal value. But I'll leave this to later cleaning after merging.
		  histogram noness_perc, bin(10) percent addlabel addlabopts(mlabsize(medsmall) mlabangle(horizontal)) xtitle(, size(small)) title(Non-essential goods expenditure percentage ,  size(medium))
		  graph export "$figures/non-essential_histogram_test.pdf", replace
		  
		  
		  gen ent_perc = (entertainment/total_exp)*100
		  label var ent_perc "Percentage of entertainment expenditure"
		  sum ent_perc 
		  
		  label var pid "Person ID"

		  save "$clean/famecon_clean", replace
		 
		 
		 
		 
********************************
***** 2. Data Preparation  *****
********************************		  
		  
		  *************************
          *** 2 (a) Merge files ***
          *************************
		  use "$clean/famecon_clean", clear
		  * merge 1:1 pid using "$input/person_clean"
		  * variable pid does not uniquely identify observations in the master data. Since person IDs are unique from each other, this only means that one person could be the respondent for more than one family. But this kind of observations won't disturb our regression analysis.
		  merge 1:1 fid18 pid using "$clean/person_clean"
		  keep if _merge == 3
		  drop _merge
		  
		  merge 1:1 fid18 using "$temp/familysize"
		  keep if _merge == 3
		  drop _merge
		  
		  merge 1:1 fid18 using "$temp/child_old_n"
		  keep if _merge == 3
		  drop _merge
		  
		  save "$clean/cfps18_clean", replace
		  
		  
		  ************************************
          *** 2 (b) Descriptive Statistics ***
          ************************************
		  
		  ***********
		  *** (i) ***
		  ***********
		  use "$clean/cfps18_clean", clear
		  * Descriptive Statistics of main independent variables
		  sum attitude
		  * Now, it can be seen that, this variable only has 100 available values. This could lead to the decrease in numbers when we run the regression. I decide not to use it。
		  drop attitude
		  sum life_sat future_con male age edu married finc savings familysize18 big_event child_n old_n urban18
		  logout, save($output/inde_summary) excel replace: sum life_sat future_con male age edu married finc savings familysize18 big_event child_n old_n urban18
		  log using "$path/Logs/Final Project", append
		  * All the ither variables have sufficient observations.
		  * the mean of life_sat is 3.95, future_con is 4.10.
		  histogram life_sat, discrete percent addlabel addlabopts(mlabsize(medsmall) mlabangle(horizontal)) 
		  graph export "$figures/Life Satisfaction.pdf", replace
		  * It can be seen that about 35% of people say they are 5/5 satisfied with their life, and 32.81% 4/5, Over 60% of the people say they're 4/5 satisfied or more.
		  histogram future_con, discrete percent addlabel addlabopts(mlabsize(medsmall) mlabangle(horizontal)) 
		  graph export "$figures/Confidence in Future.pdf", replace
		  * It can be seen that about 43.04% of people say they are 5/5 confident in their future, and 31.41% 4/5, Over 70% of the people say they're 4/5 confident or more.
		  
		  
		  
		  ************
		  *** (ii) ***
		  ************
		  * Descriptive Statisticsn of the main dependent variable
		  graph pie food clothing housing_trans med entertainment travel edu_exp percare_insurance help_out otherexp durable, sort legend(size(tiny) margin(vsmall) linegap(vsmall))
		  graph export "$figures/Pie_allexpenses.pdf", replace
		 
		  graph pie entertainment travel edu_exp percare_insurance help_out otherexp durable, sort legend(size(tiny) margin(vsmall) linegap(vsmall))
		  graph export "$figures/Pie_nonessential.pdf", replace

		  sum noness_perc
		  sum noness_perc, detail 
		  * the sknewness is .3715819, Kurtosis is 2.246925
		  histogram noness_perc, bin(10) percent addlabel addlabopts(mlabsize(medsmall) mlabangle(horizontal)) xtitle (, size(small))
		  graph export "$figures/non-essential_histogram.pdf", replace
		 
		 /* The following is not necessary. Just keeping it as mistakes. Ignore these.
		  * about 20% of the households have a 1-10% percentage. 
		  histogram noness_perc, percent 
		  * The y variable is highly skewed and definitely not normally distributed. This doesn't satisfy the assumption of OLS that the error term is normally distributed. 
		  
		  gen lnnoness_perc = ln(noness_perc)
		  histogram lnnoness_perc, percent
		  sum lnnoness_perc, detail
		  * It's even skewer, skewness -1.11, Kurtosis 3.40
		  drop lnnoness_perc
		  
		  
		  Box-Cox transformation	  
		  preserve
		  sum noness_perc, detail
		  return list
		  replace noness_perc = . if noness_perc < r(p5)
		  replace noness_perc = . if noness_perc > r(p95)
		  replace noness_perc = . if noness_perc == 0
		  boxcox noness_perc, model(lhsonly)
		  return list
		  gen bc_noness_perc = (noness_perc^(r(est))-1)/r(est)
		  sum bc_noness_perc, detail
		  hist bc_noness_perc
		  * the skewness and kurtossi only decreased by a little
		  swilk bc_noness_perc
		  *Still not nornally distributed
		  restore
		  * After trying with many processing, the dependent vairbale still shows no sign of normality. This is one limitation of the regression model and the analysis.
		  */
		
		  
		  correlate noness_perc life_sat future_con male age edu married finc savings familysize18 child_n old_n
		  logout, save($output/inde_correlation) excel replace: correlate noness_perc life_sat future_con male age edu married finc savings familysize18 child_n old_n
		  log using "$path/Logs/Final Project", append
		  * From here, you can notice that the correlation between the main independent variables are relatively high, this could result in collinearity in later analysis. To check on it, I do a factor test.
		  factortest life_sat future_con
		  * Pvalue is 0 but KMO is 0.5 < 0.6. Together, the results show no need to perform factor analysis.

		  

***********************************
***** 3. Regression Analysis  *****
***********************************			  
		  use "$clean/cfps18_clean", clear
		  
		  *********************
          *** 3 (a) Model 1 ***
          *********************	  

		  reg noness_perc life_sat future_con
		  outreg2 using "$output/Regs", excel replace ctitle(Model 1)
		  * The whole regression model is  significant, so are the regression coefficients.
		  * However, the R-sqaured is very small. Which means this model can only explain 0.55% of the variation.
		  
		  
		  *********************
          *** 3 (b) Model 2 ***
          *********************
		  * Now, since the decision of the head of the house on the expenditure of the household is also impacted by other personal and household demographical factors. In model 2, I added the demographics.
		  reg noness_perc life_sat future_con male age edu married 
		  outreg2 using "$output/Regs", excel append ctitle(Model 2)
		  * The R-squared increased a great deal, but now the two main variables have very insignificant coefficients. 
		  * This model shows that, in this case, the spending of on the houshold is not very much impacted by the individual's overall mental situation, but instead, more by the demograpgic features.

		  
		  *********************
          *** 3 (c) Model 3 ***
          *********************
		  * The spending is obviously impacted by the family's economic situation. So family total income and savings are added in.
		  
		  reg noness_perc life_sat future_con male age edu married familysize18 big_event child_n old_n finc savings urban18 i.provcd18
		  outreg2 using "$output/Regs", excel append ctitle(Model 3) drop (i.provcd18)
		  * Now, it seems that our three main independent variables are not significantly in a linear relationship with the dependent variabls. But they might be in a non-linear relatinoship. 
		  
		  
		  *********************
          *** 3 (d) Model 4 ***
          *********************
		  gen sat2= life_sat*life_sat
		  reg noness_perc life_sat sat2 future_con male age edu married finc savings familysize18 big_event child_n old_n urban18 i.provcd18
		  outreg2 using "$output/Regs", excel append ctitle(Model 4.1) drop (i.provcd18)
		   * Now As it shows, the life satisfaction variable is in a quadratic relationship with the dependent variable. But the coefficient for the other is still not significant.
		  
		  gen future2=future_con*future_con
		  reg noness_perc life_sat future_con future2 male age edu married finc savings familysize18 big_event child_n old_n urban18 i.provcd18
		  outreg2 using "$output/Regs", excel append ctitle(Model 4.2) drop (i.provcd18)
		  
		   * The future confidence variable is in a quadratic relationship with the dependent variable. But the coefficient for the other is still not significant.
		   
		  * Now I want to add btoh sqaured terms in and see how they effect the regression.
		  reg noness_perc life_sat sat2 future_con future2 male age edu married finc savings familysize18 big_event child_n old_n urban18 i.provcd18
		  outreg2 using "$output/Regs", excel append ctitle(Model 4.3) drop (i.provcd18)
		  /* wrong code, please ignore
		  estimates store regs */

		  predict noness_perc_2018
		  
		  * Now, the both main variables have significant coeeficient. But not exactly the same as assumed in the very beginning. It turns out that as life satisfaction/confidence in the future increase, the proportion of the household spending spent on the non-essential goods first decline and then increase. And the turning point is very near 0. So basically, people's spending on the non essential goods goes in the same direction of their subjective conception of their life situation. When they're more satisfied and confident about their life situation, they spend more on the non-essential goods.
		  twoway scatter  noness_perc_2018 noness_perc
		  graph export "$figures/scatter.pdf", replace
		  * The overall estimation is not so accurate. But it's still of some referential significance in that it shows that there is a certain siginificant relationship between people's mental states and their consumption pattern.
		
		
		
		  
***************************
***** 4. Implications *****
***************************			 
		  * Since the CFPS 2020 data haven't been fully released, so I can't employ the psot-epidemic data to come to a conclusion. However, the personal data have been released in the beginning of 2022. Leaving out that te factors that comes with the year itself would probably impact the relationship between the independent and dependent variables, I will use the independent variables to predict the dependent variable in 2020.
		  
		  use "$clean/person_clean", clear
		  gen year = 2018
		  save "$temp/person18_clean_for20", replace
		   
          ************************************
          *** 4 (a) Clean 2020 Person File ***
          ************************************

		  * Generate the variable for the number of children/old people in a household *
		  
		  use "$input/cfps2020person_202112", clear
		  gen year = 2020

		  * Now, generate the variables "life satisfaction", and "confidence in future" 
		  clonevar life_sat = qn12012
		  clonevar future_con = qn12016
		  
		  tab life_sat 
		  tab future_con
		  *br life_sat future_con
		  * "Not applicable" (-8) , unknown (-2) and resuse(-1) should be treated as missing values.
		  foreach var of varlist life_sat future_con{
		  replace `var' = . if `var' <0
		  }
		  sum life_sat future_con
		  
		  keep year fid18 pid life_sat future_con age gender qea0 w01
		  
		  rename qea0 marriage
		  tab marriage
		  sum marriage
		  codebook marriage
		  replace marriage = . if marriage == -8
		  replace marriage = 0 if marriage == 1 | marriage == 4 | marriage == 5 
		  replace marriage = 1 if marriage == 3 | marriage == 2
		  rename marriage married
		  label define married 1"married" 0"unmarried"
		  label value married married 
		  label var married "Whether the respondent is married"
		  
		  rename w01 edu
		  tab edu
		  codebook edu
		  * br edu
		  * "Not applicable" (-8) , unknown (-2) and resuse (-1)should be treated as missing values.
		  replace edu = . if edu < 0
		  tab edu
		  codebook edu
		  replace edu = 0 if edu == 0 | edu == 10
		  replace edu = 1 if edu == 3 | edu == 4 | edu == 5
		  replace edu = 2 if edu == 6 | edu == 7 | edu == 8 | edu == 9
		  label define edu 0"uneducated" 1"middle_edu" 2"high_edu"
		  label value edu edu
		  label var edu "The education level of the respondent"
		  sum edu
		  tab edu
		  
		  * br gender
		  * the male is "1" and female is "0"
		  rename gender male   
		  label var male "The gender of the respondent"
		  
		  /*
		  label var age "The age of the respondent"
		  label var life_sat "How satisfied are you with your life"
		  label var future_con "How confident are you in your future
		  */

		  save "$temp/main_inde_2020", replace
		  
		  ************************************ 
          *** 4 (b) Compare with 2018 data ***
          ************************************
		  use "$temp/person18_clean_for20", clear
		  append using "$temp/main_inde_2020"
		  sum
		  drop attitude
		  ssc install ttable3
		  ttable3 life_sat future_con, by(year) pvalue
		  logout, save($output/inde_1820ttable) excel replace: ttable3 life_sat future_con, by(year) pvalue
		  log using "$path/Logs/Final Project", append
		  * Surprisingly, after the pandemic, overall, people are not less satisfied with life and even more significantly confident in the future.
		  * This shows at the surveyed time, people may spend more on the non-essential goods, for example the entertainment, education, durable goods. This in a sense shed light on where the post-epidemic businesses can go.
		  
		  /* The following is wrong. Please ignore
		  estimates replay regs
		  gen noness_2020_hat =  4.041298*life_sat -.6303639*life_sat*life_sat+4.379659*future_con-.570587*future_con*future_con + 1.999518*male -.2756198*age +6.362842*edu -2.539414 if year == 2020
		  replace noness_2020_hat = . if noness_2020_hat < 0
		  * these are definitely wronng estatimates
		  sum noness_2020_hat if year == 2020
		  */
		  
		  save "$temp/implication", replace

		  
log close

* EOF
		  
		  
		
		  
		  
		  