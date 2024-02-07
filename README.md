depot
=====

[![Linux Test](https://github.com/mmitch/depot/actions/workflows/test_linux.yml/badge.svg)](https://github.com/mmitch/depot/actions/workflows/test_linux.yml)

This is a simple script to track a share portfolio.

My design goals are:

1. it's for my personal use
2. entering the transactions should make me type as little as possible

This gives some questionable results:

 * German dates
 * deciamal comma
 * EUR currency
 * weird easy to type transaction syntax
 * no distinction between ask and bid rates

If you can live with that: have fun!



usage
-----

Calling convention is `depot.pl [mode] [transaction_file]`.

If no *mode* is given the default mode will be `-default` (see below).

If no *transaction_file* is given the default filename `depot.txt`
will be used.


### modes

 * `-default` writes a short tabular summary of your portfolio to
   stdout.

 * `-verbose` writes a more detailled tabuler summary of your
   portfolio to stdout.

 * `-plot` calls _gnuplot_ to render some diagrams of your portfolio.



transaction file format
-----------------------

 * Blank lines are allowed and ignored.
 
 * `# this is a comment`  
   Lines starting with a `#` are comments and also ignored.
 
 * `+FUND some_fund`  
   Lines starting with `+FUND` define a new fund.  A fund has to be
   defined before it can be used in transactions.
   
   Fund attributes are (given in order, space-separated):
   
   1. fund name

 * `+RENAME some_fund`  
   Lines starting with `+RENAME` rename an existing fund.  In later
   lines it can only be used in transactions with the new name.

   Rename attributes are (given in order, space-separated):

   1. old fund name
   2. new fund name

 * `@@ 24.12.2021`  
   Lines starting with `@@` define the calendar day to use for the
   next transactions.
   
   The date has to be given in `dd.mm.yyyy` form.
   
 * `some_fund +1,23 = 34,16 ! 1,12`  
   Lines in this format define a transaction.
   
   Transaction attributes are (given in order, space-separated):
   
   1. fund name (must have been defined previously, to catch typos)
   2. the amount of shares bought (`+`) or sold (`-`)
   3. a fixed separator `=`
      (to denote that the shares value equals the currency amount)
   4. the EUR equivalent value of the shares
      (this is used to calculate the current rate or share price)
   5. a fixed separator `!`
   5. the EUR equivalent value of the transaction fees

So if you were to invest *80 EUR* into *fund_1*, your bank keeps *2
EUR* as a transaction fee and the remaining 78 EUR allow you to buy
*1,23 shares*, you would enter `fund_1 +1,23 = 78 ! 2`.

Look at the tests for some demo data, eg. `test/test-1-basic.input`.
