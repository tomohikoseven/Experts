//+------------------------------------------------------------------+
//|                                               Moving Average.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "tomohikoseven ver4.0"
#property link        "http://www.mql4.com"
#property description "Moving Average sample expert advisor"

#define MAGICMA  20131111
//--- Inputs
input double Lots          =0.1;
input double MaximumRisk   =0.02;
input double DecreaseFactor=3;
input int    MovingPeriod = 12;
input int    MovingPeriod_short = 12;
input int    MovingPeriod_long = 30;
input int    MovingShift   =6;
//+------------------------------------------------------------------+
//| Calculate open positions                                         |
//+------------------------------------------------------------------+
// 現在の注文数を返却する
//   買い注文>0 なら 買い注文数
//   それ以外   なら (-1)売り注文数
int CalculateCurrentOrders(string symbol)
  {
   int buys=0,sells=0;
//---
   // OrdersTotal():エントリー中の注文と保留中注文の総数を返す。
   for(int i=0;i<OrdersTotal();i++)
     {
      // 注文データを選択（注文中、保留中）
      //  注文中のデータがあるか。
      // OrderSelect( 注文インデックス、選択タイプ、注文プール ) 成功:true、失敗:false
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      
      // シンボルとマジックナンバーが同じか
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA)
        {
         // 現在選択中の注文タイプ
         if(OrderType()==OP_BUY)  buys++;
         if(OrderType()==OP_SELL) sells++;
        }
     }
//--- return orders volume
   if(buys>0) return(buys);
   else       return(-sells);
  }
//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
double LotsOptimized()
  {
   double lot=Lots;
   int    orders=HistoryTotal();     // history orders total
   int    losses=0;                  // number of losses orders without a break
//--- select lot size
   lot=NormalizeDouble(AccountFreeMargin()*MaximumRisk/1000.0,1);
//--- calcuulate number of losses orders without a break
   if(DecreaseFactor>0)
     {
      for(int i=orders-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==false)
           {
            Print("Error in history!");
            break;
           }
         if(OrderSymbol()!=Symbol() || OrderType()>OP_SELL)
            continue;
         //---
         if(OrderProfit()>0) break;
         if(OrderProfit()<0) losses++;
        }
      if(losses>1)
         lot=NormalizeDouble(lot-lot*losses/DecreaseFactor,1);
     }
//--- return lot size
   if(lot<0.1) lot=0.1;
   return(lot);
  }
//+------------------------------------------------------------------+
//| Check for open order conditions                                  |
//+------------------------------------------------------------------+
void CheckForOpen()
  {
   double ma_short_1st = 0;
   double ma_short_2nd = 0;
   double ma_long_1st = 0;
   double ma_long_2nd = 0;
   
   int    res;
//--- go trading only for first tiks of new bar
   // Volume[]:チャートの各バーのtick出来高（tick数）が含まれている時系列配列
   // 時系列配列の要素は、逆順でインデックスが付けられている。
   // チャート上の最新バーのインデックスは[0]
   // チャート上の最も古いバーのインデックスは[Bars -1]
   // 最新のtick数が1より大きい
   if(Volume[0]>1) return;
   
//--- get Moving Average 
   // iMA( 通貨ペア 時間軸（0:現在） MA平均期間 オフセット期間 MAの平均化メソッド 適用価格 シフト？ ）
   // 4h 移動平均
   ma_short_1st = iMA(NULL,PERIOD_H4,MovingPeriod_short,0/*MovingShift*/,MODE_EMA,PRICE_CLOSE,0);
   ma_short_2nd = iMA(NULL,PERIOD_H4,MovingPeriod_short,0/*MovingShift*/,MODE_EMA,PRICE_CLOSE,1);
   ma_long_1st = iMA(NULL, PERIOD_H4, MovingPeriod_long, 0 , MODE_EMA, PRICE_CLOSE, 0);
   ma_long_2nd = iMA(NULL, PERIOD_H4, MovingPeriod_long, 0 , MODE_EMA, PRICE_CLOSE, 1);
   
   if( ma_short_2nd < ma_long_2nd ){
      if( ma_long_1st < ma_short_1st ){
         res=OrderSend( Symbol(), OP_BUY , LotsOptimized() , Ask, 3, 0, 0, "", MAGICMA, 0, Blue );
         return;
      }
   }
   
   if( ma_short_2nd > ma_long_2nd ){
      if( ma_long_1st > ma_short_1st ){
         res = OrderSend( Symbol(), OP_SELL, LotsOptimized(), Bid, 3, 0, 0, "", MAGICMA, 0, Red );
         return;
      }
   }
   /*
   if( arctan > 0 ){
      //--- buy conditions
      res=OrderSend( Symbol(), OP_BUY , LotsOptimized() , Ask, 3, 0, 0, "", MAGICMA, 0, Blue );
      return;
   }
   if( arctan < 0 ){
      //--- sell conditions
      // OrderSend():売り新規注文（通貨ペア名、注文タイプ、ロット数、注文価格、スリッページ、ストップロス、利確価格、コメント、マジックナンバー、注文有効期限、チャート上の注文矢印の色）
      res = OrderSend( Symbol(), OP_SELL, LotsOptimized(), Bid, 3, 0, 0, "", MAGICMA, 0, Red );
   }
   */
  }
//+------------------------------------------------------------------+
//| Check for close order conditions                                 |
//+------------------------------------------------------------------+
void CheckForClose()
  {
   double rsi = 0;
   
//--- go trading only for first tiks of new bar
   // tick量=0だけやる、つまり時間軸が移動した最初だけ処理する制御。
   if(Volume[0]>1) return;
//--- get Moving Average 
   rsi = iRSI( NULL, PERIOD_H4, 12, PRICE_CLOSE, 0 );
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      // マジックナンバー もしくは シンボルが異なる場合 次のオーダーへ
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol()) continue;
      //--- check order type 
      if(OrderType()==OP_BUY)
        {
         if(rsi >= 70)
           {
               if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,White))
                  Print("OrderClose error ",GetLastError());
           }

         break;
        }
      if(OrderType()==OP_SELL)
        {
         if(rsi <= 30)
           {
               if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,White))
                  Print("OrderClose error ",GetLastError());
           }
         break;
        }
     }
//---
  }
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- check for history and trading
   // Bars:現在のチャートのバー数が格納
   // IsTradeAllowd() : EAのトレード許可状態
   if(Bars<100 || IsTradeAllowed()==false) return;
   
   // Time[0] = Unix時間(1970年1/1からの秒数
   if(Time[0]%1440 != 0){  // 4h経っていない場合、処理終了
     return;
   }
   
//--- calculate open orders by current symbol
   // 注文数が0 なら オープン処理
   // 注文がある（注文中、保留中） なら クローズ処理
   if(CalculateCurrentOrders(Symbol())==0)
    {
      CheckForOpen();
    }
   else
    {
      CheckForClose();
    }
//---
  }
//+------------------------------------------------------------------+
