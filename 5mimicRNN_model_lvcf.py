import pandas as pd
import tensorflow as tf
import numpy as np
import random

from datetime import datetime

from sklearn.metrics import roc_auc_score, roc_curve, auc, precision_recall_curve
from sklearn.preprocessing import StandardScaler, MinMaxScaler
from sklearn.impute import SimpleImputer
from sklearn.model_selection import train_test_split
from sklearn.utils import shuffle

print(tf.__version__)

tf.keras.utils.set_random_seed(292)

############################################################
# predict_rows     last_session     total long rows
#           24               96             6524112
#           32               64             7097952   
#           64               64            14195904
#           32               96             8698816
#           64               96            17397632
#           96               96            26096448
############################################################

# set the number of rows used in each prediction (e.g. 32 rows is 32 / 4 = 8 hours of data).
predict_rows = 96

# set the last session id (e.g. 64 is 64 / 4 = 16 hours after admission
last_session = 96

############################################################
#  read serial data
############################################################
dat = pd.read_csv('./derived/qdemo_lvcf_scaled.csv')

# data frame with unique admission ids and train flag
admit_ids = dat.filter(["admit_id","train","prlos_death"]).drop_duplicates()
admit_ids = admit_ids.sort_values(by = ["admit_id"])

# serial data
dat = dat.sort_values(by = ["admit_id","row_id"])
dat = dat.drop(["dttm","train","prlos_death","intinf","pulm_edema","pleural_eff","lptt"], axis=1)

print('serial data shape:', dat.shape)

print('admit ID data shape:', admit_ids.shape)

print('x:', range(admit_ids.shape[0]))
print('y:', np.linspace(start=8, stop=last_session, num=int(last_session/8)))
print('z:', range(-1*(predict_rows-8),last_session+1))

# like expand.grid
dat_long = np.array([(x,y,z) for x in np.array(admit_ids[["admit_id"]])[:,0] for y in np.linspace(start=8, stop=last_session, num=int(last_session/8)) for z in range(-1*(predict_rows-8),last_session+1)])
dat_long = pd.DataFrame(dat_long, columns = ['admit_id','session_id','row_id']) # rename
dat_long = dat_long.assign(predict_rows = predict_rows).astype('float64')

# create index of rows to keep, i.e. row id less than session id and within predict rows prior to session id
indx = (dat_long.row_id <= dat_long.session_id) & (dat_long.row_id > dat_long.session_id - dat_long.predict_rows)

dat_long = dat_long[(indx)].drop('predict_rows', axis=1)

# drop any session_ids that are greater than the last maximum row_id
tmp = dat.sort_values(by = ["admit_id","row_id"]).groupby(["admit_id"]).tail(n=1)
tmp["max_row_id"] = tmp["row_id"]
tmp = tmp.filter(["admit_id","max_row_id"])

dat_long = pd.merge(left=dat_long, right=tmp, on=["admit_id"], how='inner')
print('serial data shape:', dat_long.shape)

dat_long = dat_long[(dat_long["session_id"] <= dat_long["max_row_id"])].drop(["max_row_id"], axis=1)
print('serial data shape:', dat_long.shape)

# verify all session_ids have exactly predict_rows rows
tmp = dat_long.filter(["admit_id","session_id","row_id"])
tmp = tmp.sort_values(by = ["admit_id","session_id","row_id"])
tmp = tmp.assign(Count=1).groupby(["admit_id","session_id"])[["Count"]].count()
tmp = tmp.reset_index()

tmp["Count"].value_counts()

# table with the ids and the outcomes should be used here to merge outcomes and train flag (outcomes and flag should merge with all row_ids, even negative ones that dont exist in dat)
dat_long = pd.merge(left=dat_long, right=dat, on=["admit_id","row_id"], how='left')
dat_long = pd.merge(left=dat_long, right=admit_ids, on=["admit_id"], how='left')

dat_long = dat_long.sort_values(by = ["admit_id","session_id","row_id"])

# set future data to masked value
for col in dat_long.loc[:, "inicu":"vtother"].columns:
    dat_long.loc[dat_long["row_id"] > dat_long["session_id"], col] = -1
    dat_long.loc[dat_long["row_id"] < 1, col] = -1

# before icu admit
dat_long.loc[dat_long["row_id"] < 1, 'inicu'] = 0

print('serial data shape:', dat_long.shape)

dat_long = dat_long.sort_values(by = ["admit_id","session_id","row_id"])

X_mimic = dat_long[(dat_long["train"] == -999)]

ids_mimic = dat_long[(dat_long["train"] == -999)].groupby(["admit_id","session_id"]).head(n=1).filter(items=["admit_id","session_id","prlos_death"])

y_mimic = ids_mimic.filter(items=["prlos_death"])

X_mimic.shape[0] / y_mimic.shape[0]

X_mimic.shape
y_mimic.shape

# keep one row for the neural network
X1_mimic = X_mimic.groupby(["admit_id","session_id"]).tail(n=1)

# subset to features
X1_mimic = pd.concat([X1_mimic.loc[:, "row_id"], X1_mimic.loc[:, "age":"aids_hist"]], axis=1)

# subset to features
X_mimic = X_mimic.loc[:,"inicu":"vtother"]

print('LSTM training data shape:', X_mimic.shape)
print('X columns:', X_mimic.columns)

print('NN training data shape:', X1_mimic.shape)
print('X1 columns:', X1_mimic.columns)

# set the proper shapes
X1_mimic = np.array(X1_mimic)

X1_mimic = np.reshape(X1_mimic, (y_mimic.shape[0], X1_mimic.shape[1]))

# set the proper shapes
X_mimic = np.array(X_mimic)

X_mimic = np.reshape(X_mimic, (y_mimic.shape[0], predict_rows, X_mimic.shape[1]))

# load the models
model_merged_cnnsmall = tf.keras.models.load_model('../results/merged_cnnsmall_model/merged_cnnsmall_tracebacks')
model_merged_cnntiny = tf.keras.models.load_model('../results/merged_cnntiny_model/merged_cnntiny_tracebacks')
model_merged_lstmsmall = tf.keras.models.load_model('../results/merged_lstmsmall_model/merged_lstmsmall_tracebacks')
model_merged_lstmtiny = tf.keras.models.load_model('../results/merged_lstmtiny_model/merged_lstmtiny_tracebacks')

############################################################
# test mimic data
############################################################
out_mimic = ids_mimic

out_mimic["yhat_merged_cnnsmall"] = model_merged_cnnsmall.predict([X_mimic, X1_mimic])
out_mimic["yhat_merged_cnntiny"] = model_merged_cnntiny.predict([X_mimic, X1_mimic])
out_mimic["yhat_merged_lstmsmall"] = model_merged_lstmsmall.predict([X_mimic, X1_mimic])
out_mimic["yhat_merged_lstmtiny"] = model_merged_lstmtiny.predict([X_mimic, X1_mimic])

out_mimic.to_csv('../results/ztest_mimicRNN_merged_predicted.csv', index=False)

out_mimic.shape
