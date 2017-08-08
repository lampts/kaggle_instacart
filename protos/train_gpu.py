import re
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
import lightgbm as lgb
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

from utils import f1, f1_group, f1_group_idx

DIR = 'result_tmp/'


def f1_metric(label, pred):
    res = f1_group(label, pred, list_idx)
    sc = np.mean(res)
    logger.debug('f1: %s' % (sc))
    return 'f1', sc, True


def logregobj(preds, dtrain):
    """
    labels = dtrain.get_label().astype(np.int)
    preds = preds.astype(np.float)
    preds = 1.0 / (1.0 + np.exp(-preds))
    # res = f1_group_idx(labels, preds, list_idx).astype(np.bool)

    grad = preds - labels
    hess = preds * (1.0 - preds)

    # grad[res] *= 0.8
    # grad[~res] *= 1.2

    # hess[res] *= 0.8
    # hess[~res] *= 1.2
    return grad, hess
    """
    labels = dtrain.get_label()
    preds = 1. / (1. + np.exp(-preds))

    bot = 1.0e-3
    top = 1 - 1.0e-3
    preds = np.where(preds > bot, preds, bot)
    preds = np.where(preds < top, preds, top)

    grad = (preds - labels).astype(np.float32)
    hess = (preds * (1. - preds)).astype(np.float32)
    print('grad', np.isnan(grad).sum(), np.isinf(grad).sum())
    print('hess', np.isnan(hess).sum(), np.isinf(hess).sum())
    return grad, hess


def f1_metric_xgb2(pred, dtrain):
    return 'f12', pred, True


def f1_metric_xgb(pred, dtrain):
    label = dtrain.get_label().astype(np.int)
    pred = pred.astype(np.float64)
    # res = [f1(label.take(i), pred.take(i)) for i in list_idx]
    res = f1_group(label, pred, list_idx)
    sc = np.mean(res)
    logger.debug('f1: %s' % (sc))
    return 'f1', sc, True


def get_stack(folder, is_train=True):
    col = 'hogehoge'
    if is_train:
        with open(folder + 'train_cv_tmp.pkl', 'rb') as f:
            df = pd.read_csv('train_data_idx.csv', usecols=['order_id', 'user_id', 'product_id'], dtype=int)
            df[col] = pickle.load(f).astype(np.float32)
            df1 = pd.read_csv('train_data_idx.csv', usecols=['order_id', 'user_id', 'product_id'], dtype=int)
    else:
        with open(folder + 'test_tmp.pkl', 'rb') as f:
            df = pd.read_csv('test_data_idx.csv', usecols=['order_id', 'user_id', 'product_id'], dtype=int)
            df[col] = pickle.load(f).astype(np.float32)[:, 1]
            df1 = pd.read_csv('test_data_idx.csv', usecols=['order_id', 'user_id', 'product_id'], dtype=int)

    return pd.merge(df1, df, how='left', on=['order_id', 'user_id', 'product_id'])[col].values


def rrr():
    df = pd.read_csv('thresh_target.csv', header=None, names=['order_id', 'user_id', 'product_id', 'reordered'])
    return df


def _format_eval_result(value, show_stdv=True):
    """format metric string"""
    if len(value) == 4:
        return '%s\'s %s: %g' % (value[0], value[1], value[2])
    elif len(value) == 5:
        if show_stdv:
            return '%s\'s %s: %g + %g' % (value[0], value[1], value[2], value[4])
        else:
            return '%s\'s %s: %g' % (value[0], value[1], value[2])
    else:
        raise ValueError("Wrong metric value")


def callback(data):
    # if (data.iteration + 1) % 10 != 0:
    #    return

    clf = data.model
    trn_data = clf.train_set
    val_data = clf.valid_sets[0]

    preds = [ele[2] for ele in clf.eval_train(f1_metric_xgb2) if ele[1] == 'f12'][0]
    labels = trn_data.get_label().astype(np.int)

    res = f1_group_idx(labels, preds, list_idx).astype(np.bool)

    weight = np.ones(preds.shape[0])
    weight[res] = 0.8
    weight[~res] = 1.25

    trn_data.set_weight(weight)

    preds = [ele[2] for ele in clf.eval_valid(f1_metric_xgb2) if ele[1] == 'f12'][0]
    labels = val_data.get_label().astype(np.int)
    res = f1_group(labels, preds, list_idx)
    sc = np.mean(res)

    logger.info('cal [{}] {}'.format(data.iteration + 1, sc))


if __name__ == '__main__':

    from logging import StreamHandler, DEBUG, Formatter, FileHandler

    log_fmt = Formatter('%(asctime)s %(name)s %(lineno)d [%(levelname)s][%(funcName)s] %(message)s ')

    handler = StreamHandler()
    handler.setLevel('INFO')
    handler.setFormatter(log_fmt)
    logger.setLevel('INFO')
    logger.addHandler(handler)

    handler = FileHandler(DIR + 'train_gpu.py.log', 'w')
    handler.setLevel(DEBUG)
    handler.setFormatter(log_fmt)
    logger.setLevel(DEBUG)
    logger.addHandler(handler)

    logger.info('load start')
    x_train, y_train, cv = load_train_data()

    df = pd.read_csv('train_data_idx.csv', usecols=['order_id', 'user_id', 'product_id'], dtype=int)

    logger.info('merges')
    # x_train['stack1'] = get_stack('result_0727/')
    # init_score = np.log(init_score / (1 - init_score))

    id_cols = [col for col in x_train.columns.values
               if re.search('_id$', col) is not None and
               col not in set(['o_user_id', 'o_product_id', 'p_aisle_id', 'p_department_id'])]
    logger.debug('id_cols {}'.format(id_cols))
    x_train.drop(id_cols, axis=1, inplace=True)

    dropcols = sorted(list(set(x_train.columns.values.tolist()) & set(DROP_FEATURE)))
    x_train.drop(dropcols, axis=1, inplace=True)

    # imp = pd.read_csv('result_tmp/feature_importances.csv')['col'].values
    # x_train = x_train[imp[:200]]

    usecols = x_train.columns.values

    with open(DIR + 'usecols.pkl', 'wb') as f:
        pickle.dump(usecols, f, -1)
    gc.collect()

    fillna_mean = x_train.mean()
    with open(DIR + 'fillna_mean.pkl', 'wb') as f:
        pickle.dump(fillna_mean, f, -1)

    x_train = x_train.fillna(fillna_mean).values.astype(np.float32)
    x_train[np.isnan(x_train)] = -100
    x_train[np.isinf(x_train)] = -200

    logger.info('load end {}'.format(x_train.shape))

    # x_train[np.isnan(x_train)] = -100
    gc.collect()
    logger.info("data size {}".format(x_train.shape))
    logger.info('load end')
    all_params = {'max_depth': [5],
                  'learning_rate': [0.1],  # [0.06, 0.1, 0.2],
                  #'n_estimators': [3000],
                  'min_data_in_leaf': [10],
                  'feature_fraction': [0.9],
                  #'boosting_type': ['dart'],  # ['gbdt'],
                  #'xgboost_dart_mode': [False],
                  #'num_leaves': [96],
                  #'metric': ['binary_logloss'],
                  'objective': ['binary'],  # , 'xentropy'],
                  'bagging_fraction': [0.7],
                  #'min_child_samples': [10],
                  'lambda_l1': [1],
                  #'lambda_l2': [1],
                  'max_bin': [511],
                  'min_split_gain': [0],
                  #'device': ['gpu'],
                  #'gpu_platform_id': [0],
                  #'gpu_device_id': [0],
                  'verbose': [0],
                  'seed': [6436]
                  }

    min_score = (100, 100, 100)
    min_params = None
    # cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=871)
    use_score = 0

    for params in tqdm(list(ParameterGrid(all_params))):
        cnt = -1
        list_score = []
        list_score2 = []
        list_score3 = []
        list_best_iter = []
        all_pred = np.zeros(y_train.shape[0])
        for train, test in cv:
            cnt += 1
            trn_x = x_train[train]
            val_x = x_train[test]
            trn_y = y_train[train]
            val_y = y_train[test]

            list_idx = df.loc[test].reset_index(drop=True).groupby(
                'order_id').apply(lambda x: x.index.values.shape[0]).tolist()
            list_idx = np.array(list_idx, dtype=np.int)

            train_data = lgb.Dataset(trn_x, label=trn_y)
            test_data = lgb.Dataset(val_x, label=val_y)
            clf = lgb.train(params,
                            train_data,
                            3000,  # params['n_estimators'],
                            # early_stopping_rounds=30,
                            valid_sets=[test_data],
                            # callbacks=[callback]
                            feval=f1_metric_xgb,
                            fobj=logregobj
                            )
            pred = clf.predict(val_x)
            all_pred[test] = pred

            _score = log_loss(val_y, pred)
            _score2 = - roc_auc_score(val_y, pred)
            _, _score3, _ = f1_metric(val_y.astype(int), pred.astype(float))
            logger.debug('   _score: %s' % _score3)
            list_score.append(_score)
            list_score2.append(_score2)
            list_score3.append(- 1 * _score3)
            if clf.best_iteration != -1:
                list_best_iter.append(clf.best_iteration)
            else:
                list_best_iter.append(params['n_estimators'])

            with open(DIR + 'train_cv_pred_%s.pkl' % cnt, 'wb') as f:
                pickle.dump(pred, f, -1)
            with open(DIR + 'model_%s.pkl' % cnt, 'wb') as f:
                pickle.dump(clf, f, -1)
            del trn_x
            del clf
            gc.collect()
            break

        with open(DIR + 'train_cv_tmp.pkl', 'wb') as f:
            pickle.dump(all_pred, f, -1)

        logger.info('trees: {}'.format(list_best_iter))
        trees = np.mean(list_best_iter, dtype=int)
        score = (np.mean(list_score), np.min(list_score), np.max(list_score))
        score2 = (np.mean(list_score2), np.min(list_score2), np.max(list_score2))
        score3 = (np.mean(list_score3), np.min(list_score3), np.max(list_score3))

        logger.info('param: %s' % (params))
        logger.info('loss: {} (avg min max {})'.format(score[use_score], score))
        logger.info('score: {} (avg min max {})'.format(score2[use_score], score2))
        logger.info('score3: {} (avg min max {})'.format(score3[use_score], score2))
        if min_score[use_score] > score3[use_score]:
            min_score = score3
            min_score2 = score2
            min_score3 = score3
            min_params = params
        logger.info('best score: {} {}'.format(min_score[use_score], min_score))
        logger.info('best score2: {} {}'.format(min_score2[use_score], min_score2))
        logger.info('best score3: {} {}'.format(min_score3[use_score], min_score3))
        logger.info('best_param: {}'.format(min_params))

    gc.collect()
    train_data = lgb.Dataset(x_train, label=y_train)
    logger.info('train start')
    clf = lgb.train(min_params,
                    train_data,
                    3000,
                    valid_sets=[train_data])
    logger.info('train end')
    with open(DIR + 'model.pkl', 'wb') as f:
        pickle.dump(clf, f, -1)
    del x_train
    gc.collect()

    ###
    with open(DIR + 'model.pkl', 'rb') as f:
        clf = pickle.load(f)
    with open(DIR + 'usecols.pkl', 'rb') as f:
        usecols = pickle.load(f)
    imp = pd.DataFrame(clf.feature_importance(), columns=['imp'])
    imp['col'] = usecols
    n_features = imp.shape[0]
    imp = imp.sort_values('imp', ascending=False)
    imp.to_csv(DIR + 'feature_importances.csv')
    logger.info('imp use {} {}'.format(imp[imp.imp > 0].shape, n_features))

    with open(DIR + 'fillna_mean.pkl', 'rb') as f:
        fillna_mean = pickle.load(f)
    x_test = load_test_data()
    id_cols = [col for col in x_test.columns.values
               if re.search('_id$', col) is not None and
               col not in set(['o_user_id', 'o_product_id', 'p_aisle_id', 'p_department_id'])]
    logger.debug('id_cols {}'.format(id_cols))
    x_test.drop(id_cols, axis=1, inplace=True)
    x_train['stack1'] = get_stack('result_0727/', is_train=False)
    logger.info('usecols')
    # x_test['0714_10000loop'] = get_stack('0714_10000loop/', is_train=False)
    # x_test['0715_2nd_order'] = get_stack('0715_2nd_order/', is_train=False)

    # x_test.drop(usecols, axis=1, inplace=True)
    # x_test = x_test[FEATURE]

    x_test = x_test[usecols]
    gc.collect()
    logger.info('values {} {}'.format(len(usecols), x_test.shape))
    x_test.fillna(fillna_mean, inplace=True)

    if x_test.shape[1] != n_features:
        raise Exception('Not match feature num: %s %s' % (x_test.shape[1], n_features))
    logger.info('train end')
    _p_test = clf.predict(x_test)
    p_test = np.zeros((_p_test.shape[0], 2))
    p_test[:, 1] = _p_test
    with open(DIR + 'test_tmp.pkl', 'wb') as f:
        pickle.dump(p_test, f, -1)
