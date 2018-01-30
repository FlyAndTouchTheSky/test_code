//
//  ViewController.m
//  test_curl
//
//  Created by 向恒 on 2018/1/10.
//  Copyright © 2018年 向恒. All rights reserved.
//

#import "ViewController.h"
//#import "curl/curl.h"  //lib库不支持bitcode，工程里已经关闭了bitcode支持
#import "iconv/iconv.h"
#import "mosquitto/mosquitto.h"
//#import <string.h> //C语言的头文件
//#import <pthread.h>
#import "curl_test.mm"  //C++代码
@interface ViewController ()

@end

@implementation ViewController

NSString* strBuffer;
size_t write_data(void *buffer, size_t size, size_t nmemb, void *userp)
{
    size_t uLen = size*nmemb;
    
    char* s = (char*)buffer;
    
    NSString* str= [NSString stringWithUTF8String:s];
    
    strBuffer = [strBuffer stringByAppendingString:str];
    
    return uLen;
}

-(IBAction)btn_testcurl:(id)obj
{
   
    strBuffer = @"";
    
    CURL* curl;
    CURLcode res;
    res = curl_global_init(CURL_GLOBAL_DEFAULT);
    
    curl = curl_easy_init();
    if(curl == NULL)
    {
        curl_easy_cleanup(curl);
    }
    
    char* strURL = "http://192.168.2.69:8080";  //可以不带index.html
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
    curl_easy_setopt(curl, CURLOPT_URL,strURL);
    struct curl_slist * pHeaders = NULL;
    
    char* header = "";
    pHeaders = curl_slist_append(pHeaders, header);
    curl_easy_setopt(curl,CURLOPT_URL,strURL);
    curl_easy_setopt(curl,CURLOPT_HTTPHEADER,pHeaders);
    curl_easy_setopt(curl,CURLOPT_TIMEOUT, 20);
    curl_easy_setopt(curl, CURLOPT_HEADER,1);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION,&write_data);
    curl_easy_setopt(curl,CURLOPT_WRITEDATA,0);
    res = curl_easy_perform(curl);
    
    long retCode = 0;
    res = curl_easy_getinfo(curl,CURLINFO_RESPONSE_CODE,&retCode);
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    
    UIAlertView *alert0 = [[UIAlertView alloc] initWithTitle:@"Information" message:strBuffer delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert0 show];


}


//现在使用的是.a库，也可以使用系统自带的动态库
-(void) test_iconv_2
{
    
    iconv_t it;
    it = iconv_open("gbk","utf-8");
    char* str1 = "测试test";
    char* str2 = malloc(sizeof(char)*50);
    memset(str2,0,sizeof(char)*50);
    char* inBuf =str1;
    char* outBuf =str2;
    size_t inSz = strlen(str1);
    size_t outSz = inSz*2;
    size_t rst = iconv(it,&inBuf,&inSz,&outBuf,&outSz);
    printf("gbk转utf8:%s\n",str2);
    iconv_close(it);
    
    iconv_t it_gbk = iconv_open("utf-8", "gbk");
    inBuf = str2;
    char* str3 = malloc(sizeof(char)*100);
    memset(str3,0,sizeof(char)*100);
    outBuf = str3;
    inSz = strlen(str2);
    outSz = inSz*2;
    rst = iconv(it_gbk,&inBuf,&inSz,&outBuf,&outSz);
    printf("utf8转gbk:%s\n",str3);
    iconv_close(it_gbk);

    free(str2);
    free(str3);
}

-(IBAction) btn_testiconv:(id)obj
{
    [self test_iconv_2];
}


void my_message_callback(struct mosquitto *mosq, void *userdata, const struct mosquitto_message *message)
{
    if(message->payloadlen){
        printf("%s %s\n", message->topic, message->payload);
        
        //这里不能调用UIAlertView，必须要在主线程中调用
        
    }else{
        printf("%s (null)\n", message->topic);
    }
    fflush(stdout);
}

void my_connect_callback(struct mosquitto *mosq, void *userdata, int result)
{
    int i;
    if(!result){
        /* Subscribe to broker information topics on successful connect. */
        //mosquitto_subscribe(mosq, NULL, "$SYS/#", 2);
        mosquitto_subscribe(mosq, NULL, "topic", 2);
    }else{
        fprintf(stderr, "Connect failed\n");
    }
}

void my_subscribe_callback(struct mosquitto *mosq, void *userdata, int mid, int qos_count, const int *granted_qos)
{
    int i;
    
    printf("Subscribed (mid: %d): %d", mid, granted_qos[0]);
    for(i=1; i<qos_count; i++){
        printf(", %d", granted_qos[i]);
    }
    printf("\n");
}

void my_log_callback(struct mosquitto *mosq, void *userdata, int level, const char *str)
{
    /* Pring all log messages regardless of level. */
    printf("%s\n", str);
}

struct mosquitto *mosq_flag = NULL;
void* mqtt_client_thread(void* data)
{
    
    //"localhost";
    char *host = "192.168.2.69";
    int port = 1883;
    int keepalive = 60;
    bool clean_session = true;
    mosq_flag = NULL;
    struct mosquitto *mosq = NULL;
    mosquitto_lib_init();
    mosq = mosquitto_new(NULL, clean_session, NULL);
    if(!mosq){
        fprintf(stderr, "Error: Out of memory.\n");
        mosq_flag = NULL;
        return 0;
    }
    mosq_flag = mosq;
    mosquitto_log_callback_set(mosq, my_log_callback);
    mosquitto_connect_callback_set(mosq, my_connect_callback);
    mosquitto_message_callback_set(mosq, my_message_callback);
    mosquitto_subscribe_callback_set(mosq, my_subscribe_callback);
    
    if(mosquitto_connect(mosq, host, port, keepalive)){
        fprintf(stderr, "Unable to connect.\n");
        return 0;
    }
    
    mosquitto_loop_forever(mosq, -1, 1);
    
    mosquitto_destroy(mosq);
    mosquitto_lib_cleanup();
    return 1;
}

id btn_start_mosquitt = nil;
-(IBAction) btn_testmosquitto:(id)obj
{
    //gcd还没有完全搞明白，2018-01-23 14:18:36
    
     //  群组－统一监控一组任务
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_queue_t q = dispatch_get_global_queue(0, 0);
    // 添加任务
    // group 负责监控任务，queue 负责调度任务
    dispatch_group_async(group, q, ^{
        mqtt_client_thread(0);//这个调用会卡住主线程，所以需要多线程处理
        [NSThread sleepForTimeInterval:1.0];
        NSLog(@"任务1 %@", [NSThread currentThread]);
    });
//    dispatch_group_async(group, q, ^{
//        NSLog(@"任务2 %@", [NSThread currentThread]);
//    });
//    dispatch_group_async(group, q, ^{
//        NSLog(@"任务3 %@", [NSThread currentThread]);
//    });
    
    // 监听所有任务完成 － 等到 group 中的所有任务执行完毕后，"由队列调度 block 中的任务异步执行！"
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // 修改为主队列，后台批量下载，结束后，主线程统一更新UI
        //NSLog(@"OK %@", [NSThread currentThread]);
    });
    
    NSLog(@"come here");
    [obj setTitle:@"Mosquitto Running..." forState:UIControlStateDisabled];
    [obj setEnabled:NO];
    btn_start_mosquitt = obj;

}

-(IBAction)btn_testmosquitto_end:(id)sender
{
    mosquitto_loop_stop(mosq_flag,true);
    [btn_start_mosquitt setEnabled:true];
    [btn_start_mosquitt setTitle:@"Test Mosquitto"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    strBuffer = [[NSString alloc]init];  //怎么在变量定义的时候初始化
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
