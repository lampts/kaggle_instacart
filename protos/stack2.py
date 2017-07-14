
import pandas as pd
import numpy as np
import pickle
from sklearn.feature_extraction.text import TfidfVectorizer, CountVectorizer
from sklearn.model_selection import StratifiedKFold
from sklearn.linear_model import LogisticRegression
from multiprocessing import Pool
from sklearn.model_selection import GridSearchCV, ParameterGrid, StratifiedKFold, cross_val_predict
import xgboost as xgb
from lightgbm.sklearn import LGBMClassifier
from sklearn.metrics import log_loss, roc_auc_score, f1_score
import gc
from logging import getLogger
logger = getLogger(None)
import warnings
warnings.filterwarnings('ignore')

from tqdm import tqdm

from load_data import load_train_data, load_test_data
from features_drop import DROP_FEATURE
now_order_ids = None
THRESH = 0.189

list_idx = None

def aaa(arg):
    return f1_score(*arg)

def f1_metric(label, pred):
    pred = pred > THRESH
    tps = pred * label
    res = []
    for i in list_idx:
       tp = tps[i].sum()
       precision = tp / pred[i].sum()
       recall = tp / label[i].sum()
       s = (2 * precision * recall) / precision + recall
       if np.isnan(s):
           s = 0
       res.append(s)
    sc = np.mean(res)
    return 'f1', sc, True


if __name__ == '__main__':

    from logging import StreamHandler, DEBUG, Formatter, FileHandler

    log_fmt = Formatter('%(asctime)s %(name)s %(lineno)d [%(levelname)s][%(funcName)s] %(message)s ')
    handler = StreamHandler()
    handler.setLevel('INFO')
    handler.setFormatter(log_fmt)
    logger.addHandler(handler)

    handler = FileHandler('train.py.log', 'w')
    handler.setLevel(DEBUG)
    handler.setFormatter(log_fmt)
    logger.setLevel(DEBUG)
    logger.addHandler(handler)
    all_params = {'max_depth': [5],
                  'learning_rate': [0.01],  # [0.06, 0.1, 0.2],
                  'n_estimators': [10000],
                  'min_child_weight': [5],
                  'colsample_bytree': [0.7],
                  #'boosting_type': ['dart'],  # ['gbdt'],
                  #'xgboost_dart_mode': [False],
                  #'num_leaves': [96],
                  'subsample': [0.9],
                  #'min_child_samples': [10],
                  'reg_alpha': [1],
                  #'reg_lambda': [1],
                  'max_bin': [500],
                  'min_split_gain': [0],
                  'silent': [True],
                  'seed': [6436]
                  }



     
    logger.info('load start')

    df = pd.read_csv('train_data_idx.csv', usecols=['order_id', 'user_id'])
    df1 = pd.read_csv('final_data.csv', header=None,
                     names=['order_id', 'user_id', 'f1', 'idx', 'len_items', 'preds_idx', 'preds_min_idx', 'len_items', 'preds.sum_',
                            'preds.mean_', 'preds.min_', 'preds.max_', 'mean', 'std', 'map_user_order_num_user_id', 'map_reoder_rate_user_id'])    
    logger.info('m1')
    df = pd.merge(df, df1, how='left', on=['order_id', 'user_id'])
    df.drop(['order_id', 'user_id'], axis=1, inplace=True)
    logger.info('m2')
    """
    ###
    x_train, y_train, cv = load_train_data()
    x_train = x_train.merge(df, left_index=True, right_index=True, copy=False)
    usecols = sorted(list(set(x_train.columns.values.tolist()) & set(DROP_FEATURE)))
    #x_train.drop(usecols, axis=1, inplace=True)
    #df.target = y_train

    fillna_mean = x_train.mean()
    with open('fillna_mean.pkl', 'wb') as f:
        pickle.dump(fillna_mean, f, -1)

    x_train = x_train.fillna(fillna_mean).values.astype(np.float32)
    #x_train = np.c_[x_train, df]
    logger.info('m3')
    #x_train[np.isnan(x_train)] = -10
    gc.collect()

    logger.info('load end')
    #{'seed': 6436, 'n_estimators': 809, 'learning_rate': 0.1, 'silent': True, 'subsample': 0.9, 'reg_alpha': 1, 'max_depth': 5, 'colsample_bytree': 0.7, 'min_child_weight': 5, 'max_bin': 500, 'min_split_gain': 0}
    min_score = (100, 100, 100)
    min_params = None
    #cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=871)
    use_score = 0

    for params in tqdm(list(ParameterGrid(all_params))):

        cnt = 0
        list_score = []
        list_score2 = []
        list_score3 = []
        list_best_iter = []
        all_pred = np.zeros(y_train.shape[0])
        for train, test in cv:

            trn_x = x_train[train]
            val_x = x_train[test]
            trn_y = y_train[train]
            val_y = y_train[test]

            clf = LGBMClassifier(**params)
            clf.fit(trn_x, trn_y,
                    # sample_weight=trn_w,
                    # eval_sample_weight=[val_w],
                    eval_set=[(val_x, val_y)],
                    verbose=True,
                    eval_metric="auc",
                    early_stopping_rounds=30
                    )
            pred = clf.predict_proba(val_x)[:, 1]
            all_pred[test] = pred

            _score = log_loss(val_y, pred)
            _score2 = - roc_auc_score(val_y, pred)
            _score3 = - f1_score(val_y, pred > THRESH)
            logger.debug('   _score: %s' % _score)
            list_score.append(_score)
            list_score2.append(_score2)
            list_score3.append(_score3)
            if clf.best_iteration != -1:
                list_best_iter.append(clf.best_iteration)
            else:
                list_best_iter.append(params['n_estimators'])
           
            with open('train_cv_pred.pkl', 'wb') as f:
                pickle.dump(pred, f, -1)
            del trn_x
            del clf
            gc.collect()
            #break
        with open('train_cv_tmp.pkl', 'wb') as f:
            pickle.dump(all_pred, f, -1)

        logger.info('trees: {}'.format(list_best_iter))
        params['n_estimators'] = np.mean(list_best_iter, dtype=int)
        score = (np.mean(list_score), np.min(list_score), np.max(list_score))
        score2 = (np.mean(list_score2), np.min(list_score2), np.max(list_score2))
        score3 = (np.mean(list_score3), np.min(list_score3), np.max(list_score3))

        logger.info('param: %s' % (params))
        logger.info('loss: {} (avg min max {})'.format(score[use_score], score))
        logger.info('score: {} (avg min max {})'.format(score2[use_score], score2))
        logger.info('score3: {} (avg min max {})'.format(score3[use_score], score2))
        if min_score[use_score] > score[use_score]:
            min_score = score
            min_score2 = score2
            min_score3 = score3
            min_params = params
        logger.info('best score: {} {}'.format(min_score[use_score], min_score))
        logger.info('best score2: {} {}'.format(min_score2[use_score], min_score2))
        logger.info('best score3: {} {}'.format(min_score3[use_score], min_score3))
        logger.info('best_param: {}'.format(min_params))

    gc.collect()

        
    clf = LGBMClassifier(**min_params)
    clf.fit(x_train, y_train,
                    verbose=True,
                    eval_metric="auc",
            #,sample_weight=sample_weight
            )
    with open('model.pkl', 'wb') as f:
        pickle.dump(clf, f, -1)
    del x_train
    gc.collect()
    """    
    ###
    with open('model.pkl', 'rb') as f:
        clf = pickle.load(f)
    imp = pd.DataFrame(clf.feature_importances_, columns=['imp'])
    n_features = imp.shape[0]
    imp_use = imp[imp['imp'] > 0].sort_values('imp', ascending=False)
    logger.info('imp use {} {}'.format(imp_use.shape, n_features))
    with open('features_train.py', 'w') as f:
        f.write('FEATURE = [' + ','.join(map(str, imp_use.index.values)) + ']\n')

    with open('fillna_mean.pkl', 'rb') as f:
        fillna_mean = pickle.load(f)

    df = pd.read_csv('test_data_idx.csv', usecols=['order_id', 'user_id'])
    df1 = pd.read_csv('final_data_test.csv', header=None,
                     names=['order_id', 'user_id', 'f1', 'idx', 'len_items', 'preds_idx', 'preds_min_idx', 'len_items', 'preds.sum_',
                            'preds.mean_', 'preds.min_', 'preds.max_', 'mean', 'std', 'map_user_order_num_user_id', 'map_reoder_rate_user_id'])    

    df = pd.merge(df, df1, how='left', on=['order_id', 'user_id'])
    df.drop(['order_id', 'user_id'], axis=1, inplace=True)

        
    x_test = load_test_data()
    #x_test.drop(usecols, axis=1, inplace=True)
    x_test = x_test.merge(df, left_index=True, right_index=True, copy=False)
    x_test = x_test.fillna(fillna_mean).values
    
    if x_test.shape[1] != n_features:
        raise Exception('Not match feature num: %s %s' % (x_test.shape[1], n_features))
    logger.info('train end')
    p_test = clf.predict_proba(x_test)
    with open('test_tmp.pkl', 'wb') as f:
        pickle.dump(p_test, f, -1)
