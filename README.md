# Optimizing Running Performance and Efficiency with Neural Network Models

This notebook is a tool for analyzing and optimizing the performance of a running athlete. It begins by calculating various performance indices, such as VO2max (an indicator of aerobic fitness) adjusted for altitude, vVo2Max (running pace at Vo2Max), activity running speed adjusted for gradient, and the running efficiency factor (Running efficiency predictor). These values are then combined with other data, including TSS (Training Stress Score), RMSSD (Root Mean Square of the HRV Successive Differences), and nutrition data (Fiber intake).

The combined data is then split into 21-day blocks (with mean values) and fed into neural network models (MLPRegressor) to determine the "Peak performance zone," in which the athlete is most efficient, and the "Caution zone," in which they are least efficient. The corresponding training intensities/volume (TSS) and recovery metric (RMSSD) are also determined. Finally, the results are plotted on scatter and timeline plots, along with efficiency bands, to visualize the analysis.

The purpose of this notebook is to potentially help the athlete determine the optimal training intensities and volume and inform tapering before races in order to achieve the best performance and training adaptation. The data used for this analysis is from a single masters athlete and covers a period of 20 months of training at various intensities, on different terrains, at different altitudes, and with different nutritional interventions. The data is retrieved from "Athlete Data Warehouse" PostgreSQL database that combines various athletic activity/livestyle data from various sources, and exported into CSV included with this notebook.

Resources:
* https://github.com/pgalko/athlete_data_warehouse
* https://alancouzens.com/blog/Banister_v_Neural_Network.html,
* https://www.academia.edu/18970413/Heart_Rate_Running_Speed_index_May_Be_an_Efficient_Method_of_Monitoring_Endurance_Training_Adaptation,
* https://www.runnersworld.com/training/a20829802/tracking-fitness-with-the-heart-rate-running-speed-index/,
* https://dyrts.fr/en/posts/vvo2max/,
* https://pickletech.eu/blog-gap/,
* https://educatedguesswork.org/posts/grade-vs-pace/
