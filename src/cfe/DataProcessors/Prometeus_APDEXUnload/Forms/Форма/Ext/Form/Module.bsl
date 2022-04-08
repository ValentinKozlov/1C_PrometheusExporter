// Выгрузка метрик в Prometheus: удобный HTTP-клиент для 1С:Предприятие 8
//
// Copyright 2021 Valentin Kozlov
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//
//
// URL:  https://github.com/ValentinKozlov/1C_PrometheusExporter
// e-mail: i_frog@mail.ru
// Версия: 0.0.1
// Требования: платформа 1С версии 8.3.17 и выше


&НаСервере
Процедура GetAPDEXHistogramMetrics()	
	
	ПараметрыОтправки = Prometeus_MetricsProcess.ПолучитьПараметрыНастройкиОтправкиМетрикВPushgetway();
	Если ПараметрыОтправки =0 тогда
		ИмяСобытия = "Процедура Prometeus_ProcessingMetrics.ПолучитьПараметрыНастройкиОтправкиМетрикВPushgetway";
		ТекстОшибки = "Некорректно заполнены параметры отправки в Prometheus Pushgetway (Пример строки подключения: http://localhost:9091/).";
		ЗаписьЖурналаРегистрации(ИмяСобытия, УровеньЖурналаРегистрации.Предупреждение,,,ПодробноеПредставлениеОшибки(ИнформацияОбОшибке()));		
		Возврат;
	КонецЕсли;
		 
	
	//Замеряем время выполнения операции
	ВремяНачалаЗамера= ОценкаПроизводительности.НачатьЗамерВремени();

	Запрос = Новый Запрос;
	Запрос.Текст = 
		"ВЫБРАТЬ		
		|	APDEXMetrics.KeyOperation КАК KeyOperation,
		|	APDEXMetrics.APDEXbucket КАК le,
		|	СУММА(APDEXMetrics.Amount) КАК Count,
		|	СУММА(APDEXMetrics.TotalAmount) КАК Countle,		
		|	СУММА(APDEXMetrics.KeyOperationTime) КАК Sum
		|ИЗ
		|	РегистрСведений.APDEXMetrics КАК APDEXMetrics
		|
		|СГРУППИРОВАТЬ ПО		
		|	APDEXMetrics.KeyOperation,
		|	APDEXMetrics.APDEXbucket
		|
		|УПОРЯДОЧИТЬ ПО
		|	KeyOperation,
		|	APDEXbucket АВТОУПОРЯДОЧИВАНИЕ
		|
		|ИТОГИ ПО  
		|	KeyOperation
		|";
	
	РезультатЗапроса = Запрос.Выполнить();
	СпособВыборки = ОбходРезультатаЗапроса.ПоГруппировкам;
	
	ВыборкаЗаписи = РезультатЗапроса.Выбрать(СпособВыборки);          
	
	//Формируем список параметров для формирования и отправки метрик. Для корректной передачи данных нужно соблюсти
	//определенную структуру передачи параметров. Структуру СписокПараметровЗаписи прописываем для документирования
	СписокПараметровЗаписи = Новый Структура ("MetricsName, MetricsComments, DataCollection, ПараметрыОтправки"); //Описание ПараметрыОтправки есть ниже
	
	СписокПараметровЗаписи.Вставить("MetricsName","onec_business_transaction_duration_seconds_by_key_operation");
	СписокПараметровЗаписи.Вставить("MetricsComments","APDEX по ключевым операциям");
	
	LabelsList = Новый Структура;	
	DataCollection = Новый Структура;
	Data = Новый ТаблицаЗначений;	                   
	Data.Колонки.Добавить("le");
	Data.Колонки.Добавить("Countle");
		
	ТипМетрики = Перечисления.PrometheusMetricTypes.histogram; 
	
	Пока ВыборкаЗаписи.Следующий() Цикл                  	
		//Вставляем одну метку
		LabelsList.Вставить("keyoperation",ВыборкаЗаписи.KeyOperation.Наименование); 		
		
		DataCollection.Вставить("Count",ВыборкаЗаписи.Count);
		DataCollection.Вставить("Sum",ВыборкаЗаписи.Sum);		
		
		Data.Очистить();
		ВыборкаДетальнойЗаписи = ВыборкаЗаписи.Выбрать();		
		Пока ВыборкаДетальнойЗаписи.Следующий() Цикл
			Стр=Data.Добавить();
			Стр.le=ВыборкаДетальнойЗаписи.le;
			Стр.Countle=ВыборкаДетальнойЗаписи.Countle;
 		КонецЦикла;
			
		DataCollection.Вставить("Data",Data);
		СписокПараметровЗаписи.Вставить("DataCollection",DataCollection);      
		
		//Для отправки метрики требуется 5 параметров: URL_Pushgetway,JobName, InstanceName, LabelsList, MetricsBody 
	    //4 из них формируется в начале отправке при сборе данных. MetricsBody формируется в функции ЗаписатьМетрикуВPushgetway 
		ПараметрыОтправки.Вставить("LabelsList",LabelsList);
		СписокПараметровЗаписи.Вставить("ПараметрыОтправки",ПараметрыОтправки);
		Если Prometeus_MetricsProcess.ЗаписатьМетрикуВPushgetway(СписокПараметровЗаписи,ТипМетрики)=0 Тогда
			Сообщить("Ошибка выгрузки метрик. Детали смотрите в журнале регистрации.");
			Прервать;
		КонецЕсли;
	КонецЦикла;                                                                                                                                
	
	ОценкаПроизводительности.ЗакончитьЗамерВремени("Регламентное задание ""Push prometheus metrics"" ",ВремяНачалаЗамера,,"Выгрузка метрик с типом histogram в Pushgetway");	
			
КонецПроцедуры 


&НаКлиенте
Процедура ОтправитьвPuhgetway(Команда)
	GetAPDEXHistogramMetrics();
	ПоказатьПредупреждение(,"Операция выгрузки метрик завершена!");

КонецПроцедуры
